// lib/services/sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';
import '../models/sync_queue_item.dart';
import '../utils/notifiers.dart';
import '../services/user_session.dart';

class SyncService {
  SyncService._privateConstructor();
  static final SyncService instance = SyncService._privateConstructor();

  final CacheService _cacheService = CacheService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  bool _isSyncing = false;
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _connectivityService.isOnlineNotifier.addListener(_onConnectivityChanged);
    debugPrint("[SyncService] Başlatıldı ve bağlantı durumunu dinliyor.");
    _isInitialized = true;
    if (_connectivityService.isOnlineNotifier.value) {
      processQueue();
    }
  }

  void _onConnectivityChanged() {
    if (_connectivityService.isOnlineNotifier.value) {
      debugPrint("[SyncService] Bağlantı geri geldi. Senkronizasyon kuyruğu işleniyor...");
      processQueue();
    }
  }

  Future<void> processQueue() async {
    if (_isSyncing) {
      debugPrint("[SyncService] Zaten bir senkronizasyon işlemi devam ediyor.");
      return;
    }
    
    final itemsToSync = _cacheService.getPendingSyncItems();
    if (itemsToSync.isEmpty) {
      debugPrint("[SyncService] Senkronize edilecek bekleyen işlem yok.");
      return;
    }

    _isSyncing = true;
    int successCount = 0;
    debugPrint("[SyncService] Kuyrukta ${itemsToSync.length} işlem bulundu. İşleme başlanıyor.");

    itemsToSync.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final item in itemsToSync) {
      if (!_connectivityService.isOnlineNotifier.value) {
        debugPrint("[SyncService] Senkronizasyon sırasında bağlantı koptu. İşlem durduruldu.");
        break;
      }

      debugPrint("--- [SyncService] İşleniyor: ID: ${item.id}, Tip: ${item.type}, Deneme: ${item.retryCount} ---");

      try {
        item.status = 'syncing';
        await _cacheService.updateSyncItem(item);
        
        bool success = await _dispatch(item);

        if (success) {
          debugPrint("[SyncService] BAŞARILI: İşlem #${item.id} (${item.type}) senkronize edildi.");
          if(item.type == 'create_order') {
            await _cacheService.deleteTemporaryOrder(item.id);
          }
          await _cacheService.deleteSyncItem(item);
          successCount++;
        } else {
          item.status = 'failed';
          item.retryCount++;
          await _cacheService.updateSyncItem(item);
          debugPrint("[SyncService] BAŞARISIZ: İşlem #${item.id} senkronize edilemedi. Hata durumuna alındı.");
        }
      } catch (e) {
        debugPrint("[SyncService] Kuyruk işlenirken kritik hata: $e");
        item.status = 'failed';
        item.retryCount++;
        await _cacheService.updateSyncItem(item);
      }
    }

    _isSyncing = false;
    debugPrint("[SyncService] Kuyruk işleme tamamlandı.");
    
    if (successCount > 0) {
      syncStatusMessageNotifier.value = "$successCount adet bekleyen işlem başarıyla senkronize edildi.";
    }

    shouldRefreshTablesNotifier.value = true;
  }

  Future<bool> _dispatch(SyncQueueItem item) async {
    try {
      final payloadString = utf8.decode(base64Decode(item.payload));
      final payload = jsonDecode(payloadString);
      debugPrint("[SyncService._dispatch] Tip: ${item.type}, Payload: $payload");

      switch (item.type) {
        case 'create_order':
          final url = ApiService.getUrl('/orders/');
          final response = await http.post(
            url,
            headers: {"Content-Type": "application/json", "Authorization": "Bearer ${UserSession.token}"},
            body: jsonEncode(payload),
          );
          if (response.statusCode == 201) {
            final newOrderData = jsonDecode(utf8.decode(response.bodyBytes));
            final int permanentId = newOrderData['id'];
            final String tempId = item.id;
            debugPrint("[SyncService._dispatch] 'create_order' başarılı. Geçici ID: $tempId -> Kalıcı ID: $permanentId");
            await _updateDependentTasks(tempId, permanentId);
            return true;
          }
          debugPrint("[SyncService._dispatch] 'create_order' API hatası: ${response.statusCode} - ${response.body}");
          return false;

        case 'mark_as_paid':
          final orderId = payload['orderId'];
          
          // GÜVENLİK KONTROLÜ: Eğer orderId hala geçici bir UUID ise, bu görev henüz işlenemez.
          // Bu, create_order görevinin henüz tamamlanmadığı anlamına gelir.
          if (orderId == null || orderId is! int) {
            debugPrint("[SyncService._dispatch] HATA: 'mark_as_paid' için orderId sayısal değil. Görev atlanıyor. ID: $orderId");
            return false; // Bu görevi daha sonra tekrar denemek için kuyrukta bırak.
          }
          
          final url = ApiService.getUrl('/orders/$orderId/mark-as-paid/');
          final response = await http.post(
            url,
            headers: {"Content-Type": "application/json", "Authorization": "Bearer ${UserSession.token}"},
            body: jsonEncode(payload), // payload zaten 'orderId' dışında gerekli alanları içeriyor.
          );
          if (response.statusCode != 200) {
            debugPrint("[SyncService._dispatch] 'mark_as_paid' API hatası: ${response.statusCode} - ${response.body}");
          }
          return response.statusCode == 200;

        case 'add_order_item':
          final orderId = payload['orderId'];
          if (orderId == null || orderId is! int) {
            debugPrint("[SyncService._dispatch] HATA: add_order_item için orderId sayısal değil. Görev atlanıyor.");
            return false;
          }
          final url = ApiService.getUrl('/orders/$orderId/add-item/');
          final response = await http.post(
            url,
            headers: {"Content-Type": "application/json", "Authorization": "Bearer ${UserSession.token}"},
            body: jsonEncode(payload),
          );
          if (response.statusCode != 200 && response.statusCode != 201) {
            debugPrint("[SyncService._dispatch] 'add_order_item' API hatası: ${response.statusCode} - ${response.body}");
          }
          return response.statusCode == 201 || response.statusCode == 200;

        case 'delete_order_item':
          final orderItemId = payload['order_item_id'];
          if (orderItemId == null || orderItemId is! int) return false;
          final url = ApiService.getUrl('/order_items/$orderItemId/');
          final response = await http.delete(
            url,
            headers: {"Authorization": "Bearer ${UserSession.token}"},
          );
          return response.statusCode == 204;

        default:
          debugPrint("[SyncService._dispatch] Bilinmeyen işlem tipi: ${item.type}");
          return false;
      }
    } catch (e) {
      debugPrint("[SyncService._dispatch] Görev işlenirken hata: $e");
      return false;
    }
  }

  Future<void> _updateDependentTasks(String tempOrderId, int permanentOrderId) async {
    debugPrint("[SyncService] Bağımlı görevler güncelleniyor. Geçici ID: $tempOrderId -> Kalıcı ID: $permanentOrderId");
    
    // Değiştirilecek öğelerin bir listesini oluşturuyoruz, çünkü döngü sırasında Hive kutusunu değiştiremeyiz.
    List<SyncQueueItem> itemsToUpdate = [];
    final allPendingItems = _cacheService.getPendingSyncItems();
    
    for (final item in allPendingItems) {
      // Sadece siparişe ait diğer işlemleri kontrol et (ürün ekleme, ödeme yapma vb.)
      if (item.type == 'add_order_item' || item.type == 'mark_as_paid') {
        try {
          final payloadString = utf8.decode(base64Decode(item.payload));
          var payload = jsonDecode(payloadString) as Map<String, dynamic>;
          debugPrint("[SyncService._updateDependentTasks] Kuyruk taranıyor... Mevcut işlem: #${item.id}, Tip: ${item.type}, Payload: $payload");

          // Payload'daki 'orderId' alanının geçici ID ile eşleşip eşleşmediğini kontrol et
          if (payload['orderId'] == tempOrderId) {
            debugPrint("[SyncService] EŞLEŞME BULUNDU! Görev ID: #${item.id}. OrderId, $permanentOrderId olarak güncelleniyor.");
            
            payload['orderId'] = permanentOrderId;
            item.payload = base64Encode(utf8.encode(jsonEncode(payload)));
            itemsToUpdate.add(item);
          } else {
            debugPrint("[SyncService._updateDependentTasks] Görev #${item.id} bağımlı değil. (Beklenen: $tempOrderId, Bulunan: ${payload['orderId']})");
          }
        } catch (e) {
          debugPrint("[SyncService._updateDependentTasks] Bağımlı görev güncellenirken payload okunurken hata: $e");
        }
      }
    }
    
    // Toplanan tüm güncellenecek öğeleri Hive'a yaz.
    for (final itemToUpdate in itemsToUpdate) {
      await _cacheService.updateSyncItem(itemToUpdate);
      debugPrint("[SyncService] Bağımlı görev #${itemToUpdate.id} başarıyla güncellendi.");
    }
  }

  void dispose() {
    _connectivityService.isOnlineNotifier.removeListener(_onConnectivityChanged);
    debugPrint("[SyncService] Durduruldu.");
    _isInitialized = false;
  }
}
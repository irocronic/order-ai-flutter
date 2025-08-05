// lib/services/cache_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/sync_queue_item.dart';
import '../models/printer_config.dart';

/// Hive veritabanı ile tüm etkileşimleri yöneten servis.
class CacheService {
  CacheService._privateConstructor();
  static final CacheService instance = CacheService._privateConstructor();

  // Box isimleri
  static const String _settingsBoxName = 'settings';
  static const String _menuBoxName = 'menu_cache';
  static const String _syncQueueBoxName = 'sync_queue';
  static const String _tempOrdersBoxName = 'temporary_orders';
  static const String _printersBoxName = 'printers';

  final ValueNotifier<int> syncQueueCountNotifier = ValueNotifier(0);

  /// Servisi başlatır. main.dart'ta çağrılacak.
  Future<void> initialize() async {
    await Hive.openBox(_settingsBoxName);
    await Hive.openBox<Map>(_menuBoxName);
    await Hive.openBox<SyncQueueItem>(_syncQueueBoxName);
    await Hive.openBox<Map>(_tempOrdersBoxName);
    await Hive.openBox<PrinterConfig>(_printersBoxName);
    updateQueueCount();
  }

  // Box getter'ları
  Box<SyncQueueItem> get syncQueueBox => Hive.box<SyncQueueItem>(_syncQueueBoxName);
  Box<Map> get menuCacheBox => Hive.box<Map>(_menuBoxName);
  Box get settingsBox => Hive.box(_settingsBoxName);
  Box<Map> get tempOrdersBox => Hive.box<Map>(_tempOrdersBoxName);
  Box<PrinterConfig> get printersBox => Hive.box<PrinterConfig>(_printersBoxName);

  void updateQueueCount() {
    syncQueueCountNotifier.value = syncQueueBox.values.where((item) => item.status == 'pending' || item.status == 'failed').length;
    debugPrint("[CacheService] Kuyruk sayısı güncellendi: ${syncQueueCountNotifier.value}");
  }

  // --- Yazıcı Yönetimi Metotları ---

  /// Tüm kayıtlı yazıcıları getirir.
  List<PrinterConfig> getPrinters() {
    return printersBox.values.toList();
  }

  /// Yeni bir yazıcı ekler veya mevcut olanı günceller.
  Future<void> savePrinter(PrinterConfig printer) async {
    await printersBox.put(printer.id, printer);
    debugPrint("[CacheService] Yazıcı kaydedildi: ${printer.name} (${printer.ipAddress})");
  }

  /// Bir yazıcıyı siler.
  Future<void> deletePrinter(String printerId) async {
    await printersBox.delete(printerId);
    debugPrint("[CacheService] Yazıcı silindi: ID $printerId");
  }
  
  // --- Senkronizasyon Kuyruğu İşlemleri ---
  Future<void> addToSyncQueue(SyncQueueItem item) async {
    await syncQueueBox.put(item.id, item);
    updateQueueCount();
  }

  List<SyncQueueItem> getPendingSyncItems() {
    return syncQueueBox.values.where((item) => item.status == 'pending' || item.status == 'failed').toList();
  }

  Future<void> updateSyncItem(SyncQueueItem item) async {
    await syncQueueBox.put(item.id, item);
    updateQueueCount();
  }

  Future<void> deleteSyncItem(SyncQueueItem item) async {
    await syncQueueBox.delete(item.id);
    updateQueueCount();
  }

  // --- Geçici Sipariş Önbelleği İşlemleri ---
  Future<void> cacheTemporaryOrder(Map<String, dynamic> orderData) async {
    final String tempId = orderData['temp_id'] as String? ?? orderData['id'].toString();
    await tempOrdersBox.put(tempId, orderData);
    debugPrint("[CacheService] Geçici sipariş önbelleğe alındı. ID: $tempId");
  }

  List<Map<String, dynamic>> getTemporaryOrders() {
    final orders = tempOrdersBox.values.map((map) => Map<String, dynamic>.from(map)).toList();
    debugPrint("[CacheService] ${orders.length} adet geçici sipariş önbellekten okundu.");
    return orders;
  }

  Future<void> deleteTemporaryOrder(String tempId) async {
    await tempOrdersBox.delete(tempId);
    debugPrint("[CacheService] Geçici sipariş önbellekten silindi. ID: $tempId");
  }
  
  /// Mevcut bir geçici siparişi günceller veya yenisini ekler.
  /// Çevrimdışı modda siparişe ürün ekleme/çıkarma sonrası kullanılır.
  Future<void> updateCachedOrder(Map<String, dynamic> updatedOrderData) async {
    final String? tempId = updatedOrderData['temp_id'] as String?;
    final int? orderId = updatedOrderData['id'] as int?;

    if (tempId != null) {
      await tempOrdersBox.put(tempId, updatedOrderData);
      debugPrint("[CacheService] Geçici sipariş (temp_id: $tempId) güncellendi.");
    } else if (orderId != null) {
      // Eğer senkronize olmuş bir sipariş offline'da güncellenirse, onu da geçici olarak sakla
      await tempOrdersBox.put(orderId.toString(), updatedOrderData);
      debugPrint("[CacheService] Online sipariş (id: $orderId) çevrimdışı güncellendi ve önbelleğe alındı.");
    }
  }

  // --- Veri Önbellekleme İşlemleri ---
  Future<void> cacheData(String key, List<dynamic> data) async {
    await menuCacheBox.put(key, {'data': data});
  }

  List<dynamic>? getCachedData(String key) {
    final cached = menuCacheBox.get(key);
    if (cached != null && cached['data'] is List) {
      return cached['data'] as List<dynamic>;
    }
    return null;
  }
}
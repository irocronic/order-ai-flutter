// lib/services/socket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Random için eklendi
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/widgets.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'user_session.dart';
import '../utils/notifiers.dart';
import '../models/notification_event_types.dart';

class SocketService extends ChangeNotifier {
  // --- Singleton Pattern Başlangıcı ---
  SocketService._privateConstructor();
  static final SocketService instance = SocketService._privateConstructor();
  // --- Singleton Pattern Sonu ---

  IO.Socket? _socket;
  final ValueNotifier<String> connectionStatusNotifier =
      ValueNotifier('Bağlantı bekleniyor...');
  final ValueNotifier<List<Map<String, String>>> notificationHistoryNotifier =
      ValueNotifier([]);

  String? _currentKdsRoomSlug;
  bool _isDisposed = false;

  // <<< DEĞİŞİKLİK BAŞLANGICI: Eski de-duplication değişkenleri kaldırıldı >>>
  // String _lastNotificationId = '';
  // DateTime _lastNotificationTime = DateTime.now();
  
  // Son işlenen bildirim ID'lerini tutacak bir liste. Bellekte şişmemesi için boyutunu sınırlı tutuyoruz.
  final List<String> _processedNotificationIds = [];
  // <<< DEĞİŞİKLİK SONU >>>

  IO.Socket? get socket => _socket;

  static const Set<String> _loudNotificationEvents = {
    NotificationEventTypes.guestOrderPendingApproval,
    NotificationEventTypes.existingOrderNeedsReapproval,
    NotificationEventTypes.orderApprovedForKitchen,
    NotificationEventTypes.orderReadyForPickupUpdate,
    NotificationEventTypes.orderItemAdded
  };

  static const Set<String> _infoNotificationEvents = {
    NotificationEventTypes.waitingCustomerAdded,
    'secondary_info_update',
  };

  void connectAndListen() {
    if (_isDisposed) {
      debugPrint("[SocketService] Dispose edilmiş servis yeniden canlandırılıyor.");
      _isDisposed = false;
    }

    if (_socket != null && _socket!.connected) {
      debugPrint("[SocketService] Zaten bağlı.");
      if (_currentKdsRoomSlug != null && UserSession.token.isNotEmpty) {
        joinKdsRoom(_currentKdsRoomSlug!);
      }
      return;
    }
    if (UserSession.token.isEmpty) {
      debugPrint(
          "[SocketService] Token bulunamadığı için socket bağlantısı kurulmuyor.");
      connectionStatusNotifier.value = 'Bağlantı için token gerekli.';
      return;
    }

    String baseSocketUrl = ApiService.baseUrl.replaceAll('/api', '');
    if (baseSocketUrl.endsWith('/')) {
      baseSocketUrl = baseSocketUrl.substring(0, baseSocketUrl.length - 1);
    }

    _socket = IO.io(
      baseSocketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io/')
          .setAuth({'token': UserSession.token})
          .disableAutoConnect()
          .setTimeout(20000)
          .setReconnectionAttempts(5)
          .setReconnectionDelay(3000)
          .build(),
    );

    _registerListeners();
    if (_socket?.connected == false) {
      _socket!.connect();
    }
    debugPrint("[SocketService] Socket bağlantısı deneniyor: $baseSocketUrl");
  }

  void _registerListeners() {
    if (_socket == null) return;
    _socket!.clearListeners();

    _socket!.onConnect((_) {
      debugPrint(
          "🔌 [SocketService] Fiziksel bağlantı kuruldu. Sunucudan 'connected_and_ready' olayı bekleniyor... SID: ${_socket?.id}");
      connectionStatusNotifier.value = 'Sunucu onayı bekleniyor...';
    });

    _socket!.on('connected_and_ready', (_) {
      debugPrint(
          "✅ [SocketService] Sunucudan 'connected_and_ready' onayı alındı. Bağlantı tam olarak hazır.");
      connectionStatusNotifier.value = 'Bağlandı';

      if (_currentKdsRoomSlug != null && UserSession.token.isNotEmpty) {
        joinKdsRoom(_currentKdsRoomSlug!);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        shouldRefreshTablesNotifier.value = true;
        shouldRefreshWaitingCountNotifier.value = true;
      });
      _addNotificationToHistory("Bağlantı başarılı.", "system_connect");
    });

    _socket!.onDisconnect((reason) {
      debugPrint("🔌 [SocketService] Bağlantı koptu. Sebep: $reason");
      connectionStatusNotifier.value = 'Bağlantı koptu. Tekrar deneniyor...';
      _addNotificationToHistory("Bağlantı koptu.", "system_disconnect");

      Future.delayed(Duration(seconds: 2 + Random().nextInt(3)), () {
        if (!_isDisposed && (_socket == null || !_socket!.connected)) {
          debugPrint("[SocketService] Otomatik yeniden bağlanma deneniyor...");
          connectAndListen();
        }
      });
    });

    _socket!.onConnectError((data) {
      debugPrint("❌ [SocketService] Bağlantı Hatası: $data");
      connectionStatusNotifier.value = 'Bağlantı hatası.';
      _addNotificationToHistory("Bağlantı hatası.", "system_connect_error");
    });

    _socket!.onError((data) {
      debugPrint("❗ [SocketService] Genel Hata: $data");
      _addNotificationToHistory("Sistem hatası.", "system_error");
    });

    _socket!.on('order_status_update', (data) {
      if (data is! Map<String, dynamic>) return;
      
      // <<< GÜNCELLEME BAŞLANGICI: Zaman bazlı kontrol yerine ID bazlı kontrol >>>
      
      // 1. Backend'den gelen benzersiz bildirim ID'sini al
      final String? notificationId = data['notification_id'] as String?;

      // 2. Eğer ID yoksa veya bu ID'yi daha önce işlemişsek, fonksiyonu sonlandır.
      if (notificationId == null || _processedNotificationIds.contains(notificationId)) {
        debugPrint("📨 [SocketService] Tekrarlı veya ID'siz bildirim engellendi: ${notificationId ?? 'ID YOK'}");
        return;
      }
      
      // 3. Bu yeni bir bildirim. ID'sini listeye ekle.
      _processedNotificationIds.add(notificationId);
      
      // 4. Bellekte sonsuza kadar ID birikmesini önlemek için listeyi temizle (son 50 ID'yi tut).
      if (_processedNotificationIds.length > 50) {
        _processedNotificationIds.removeRange(0, _processedNotificationIds.length - 50);
      }
      
      // <<< GÜNCELLEME SONU >>>

      debugPrint("📨 [SocketService] 'order_status_update' işleniyor: $data");

      final String? eventType = data['event_type'] as String?;
      if (eventType == null) return;

      orderStatusUpdateNotifier.value = Map<String, dynamic>.from(data);
      shouldRefreshTablesNotifier.value = true;

      if (UserSession.hasNotificationPermission(eventType)) {
        debugPrint(
            "[SocketService] Kullanıcı ('${UserSession.username}') '$eventType' için bildirim iznine sahip. İlgili aksiyonlar tetiklenecek.");
        _addNotificationToHistory(
            data['message'] ?? 'Sipariş durumu güncellendi.', eventType);

        if (_loudNotificationEvents.contains(eventType)) {
          newOrderNotificationDataNotifier.value = Map<String, dynamic>.from(data);
          if (!kIsWeb) {
            try {
              FlutterRingtonePlayer().playNotification(asAlarm: true);
            } catch (e) {
              debugPrint("Ringtone error (loud event): $e");
            }
          }
        } else if (_infoNotificationEvents.contains(eventType)) {
          informationalNotificationNotifier.value =
              Map<String, dynamic>.from(data);
        }
      } else {
        debugPrint(
            "[SocketService] Kullanıcı ('${UserSession.username}') '$eventType' için bildirim iznine sahip değil. Sadece arayüz güncellendi, sesli/görsel uyarı gösterilmeyecek.");
      }
    });

    _socket!.on('waiting_list_update', (data) {
      debugPrint("📨 [SocketService] 'waiting_list_update' alındı: $data");
      if (data is! Map<String, dynamic>) return;

      final String? eventType = data['event_type'] as String?;
      if (eventType == null || !UserSession.hasNotificationPermission(eventType)) {
        return;
      }

      _addNotificationToHistory(
          data['message'] ?? 'Bekleme listesi güncellendi.', eventType);
      waitingListChangeNotifier.value = Map<String, dynamic>.from(data);
      shouldRefreshWaitingCountNotifier.value = true;

      if (eventType == NotificationEventTypes.waitingCustomerAdded) {
        if (!kIsWeb) {
          try {
            FlutterRingtonePlayer().playNotification();
          } catch (e) {
            debugPrint("Ringtone error (waiting): $e");
          }
        }
      }
    });

    _socket!.on('pager_event', (data) {
      debugPrint("📨 [SocketService] 'pager_event' alındı: $data");
      if (data is Map<String, dynamic> &&
          data['event_type'] == 'pager_status_updated') {
        _addNotificationToHistory(
            data['message'] ?? 'Pager durumu güncellendi.', 'pager_status_updated');
        pagerStatusUpdateNotifier.value = Map<String, dynamic>.from(data);
      }
    });

    _socket!.on('stock_alert', (data) {
      debugPrint("📨 [SocketService] 'stock_alert' alındı: $data");
      if (data is Map<String, dynamic> && data['alert'] is bool) {
        _addNotificationToHistory(
            data['message'] ?? 'Stok durumu güncellendi.', 'stock_adjusted');
        stockAlertNotifier.value = data['alert'];
      }
    });

    debugPrint(
        "[SocketService] Tüm socket listener'ları kaydedildi/güncellendi.");
  }

  void _addNotificationToHistory(String message, String eventType) {
    final timeStampedMessage =
        '[${DateFormat('HH:mm:ss').format(DateTime.now())}] $message';
    final currentHistory =
        List<Map<String, String>>.from(notificationHistoryNotifier.value);
    currentHistory
        .insert(0, {'message': timeStampedMessage, 'eventType': eventType});
    if (currentHistory.length > 100) {
      currentHistory.removeLast();
    }
    notificationHistoryNotifier.value = currentHistory;
  }

  void joinKdsRoom(String kdsSlug) {
    if (_socket != null && _socket!.connected) {
      if (UserSession.token.isEmpty) {
        debugPrint(
            "[SocketService] KDS odasına katılmak için token gerekli, ancak token yok.");
        return;
      }

      final payload = {'token': UserSession.token, 'kds_slug': kdsSlug};
      debugPrint(
          "[SocketService] 'join_kds_room' eventi gönderiliyor. Slug: $kdsSlug, SID: ${_socket?.id}");
      _socket!.emit('join_kds_room', payload);
      _currentKdsRoomSlug = kdsSlug;
    } else {
      _currentKdsRoomSlug = kdsSlug;
      debugPrint(
          "[SocketService] Socket bağlı değil. KDS odasına katılım isteği ('$kdsSlug') bağlantı kurulunca yapılacak.");
      if (_socket?.connected == false && UserSession.token.isNotEmpty) {
        _socket?.connect();
      }
    }
  }

  void reset() {
    if (_socket != null && _socket!.connected) {
      debugPrint("[SocketService] Bağlantı resetleniyor...");
      _socket!.disconnect();
    }
    _socket?.clearListeners();
    _socket?.dispose();
    _socket = null;
    _currentKdsRoomSlug = null;
    connectionStatusNotifier.value = 'Bağlantı bekleniyor...';
    debugPrint("[SocketService] Servis durumu sıfırlandı.");
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint("[SocketService] Dispose ediliyor...");
    reset();
    super.dispose();
    debugPrint("[SocketService] Dispose tamamlandı.");
  }
}
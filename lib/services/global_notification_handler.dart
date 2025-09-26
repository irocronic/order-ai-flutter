// lib/services/global_notification_handler.dart

import '../services/notification_center.dart';
import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../main.dart';
import '../utils/notifiers.dart';
import '../services/user_session.dart';
import '../models/notification_event_types.dart';
import '../widgets/notifications/notification_ui_helper.dart';
// Dialog widget'larını import ediyoruz
import '../widgets/dialogs/order_approved_for_kitchen_dialog.dart';
import '../widgets/dialogs/order_ready_for_pickup_dialog.dart';
// YENİ: Dil bilgisine erişim için LanguageProvider import edildi
import '../providers/language_provider.dart';

class GlobalNotificationHandler {
  static GlobalNotificationHandler? _instance;

  static GlobalNotificationHandler get instance {
    _instance ??= GlobalNotificationHandler._internal();
    return _instance!;
  }

  GlobalNotificationHandler._internal();

  static void cleanup() {
    if (_instance != null) {
      debugPrint("[GlobalNotificationHandler] cleanup() çağrıldı - disposing instance.");
      try {
        newOrderNotificationDataNotifier.removeListener(_handleNewNotification);
      } catch (e) {
        debugPrint("[GlobalNotificationHandler] cleanup removeListener hatası: $e");
      }
      _instance?.dispose();
    }
    _instance = null;
    _isInitialized = false;
    debugPrint("[GlobalNotificationHandler] Singleton instance disposed and removed.");
  }

  static final AudioPlayer _audioPlayer = AudioPlayer();
  final Queue<Map<String, dynamic>> _notificationQueue = Queue<Map<String, dynamic>>();
  final Set<String> _processedBannerIds = <String>{};
  bool _isProcessing = false;
  bool _isBannerShowing = false;
  static bool _isAppInForeground = true;

  bool _isSoundPlaying = false;
  Timer? _soundCooldownTimer;
  static const Duration _soundCooldown = Duration(seconds: 3);

  Timer? _bannerTimeoutTimer;
  bool _bannerTimedOut = false;

  bool _isDisposed = false;
  static bool _isInitialized = false;
  
  // HATA DÜZELTME: Bu değişkenin bir kopyası KDS ekranında vardı, bu merkezi olan.
  bool _isDialogShowing = false;

  static final Set<String> _pendingRefreshes = <String>{};
  static Timer? _refreshDebounceTimer;

  static void updateAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    debugPrint("[GlobalNotificationHandler] App Lifecycle State Updated: $_isAppInForeground");
    if (_isAppInForeground) {
      if (_instance != null && !_instance!._isDisposed) {
        try {
          instance.processPendingNotifications();
        } catch (e) {
          debugPrint("[GlobalNotificationHandler] updateAppLifecycleState processPendingNotifications hata: $e");
        }
      }
    }
  }

  static final Map<String, Duration> _bannerDurations = <String, Duration>{
    NotificationEventTypes.orderApprovedForKitchen: const Duration(seconds: 5),
    NotificationEventTypes.orderReadyForPickupUpdate: const Duration(seconds: 5),
    NotificationEventTypes.orderItemAdded: const Duration(seconds: 4),
    NotificationEventTypes.orderPreparingUpdate: const Duration(seconds: 3),
    NotificationEventTypes.guestOrderPendingApproval: const Duration(seconds: 5),
    NotificationEventTypes.existingOrderNeedsReapproval: const Duration(seconds: 5),
    'order_approved_for_kitchen': const Duration(seconds: 5),
    'order_ready_for_pickup_update': const Duration(seconds: 5),
    'order_preparing_update': const Duration(seconds: 3),
    'order_pending_approval': const Duration(seconds: 5),
    'new_order_notification': const Duration(seconds: 5),
  };
  static const Duration _defaultBannerDuration = Duration(seconds: 3);

  static void initialize() {
    if (_isInitialized) {
      debugPrint("[GlobalNotificationHandler] initialize() zaten çağrılmış, atlanıyor.");
      return;
    }
    debugPrint("[GlobalNotificationHandler] 🚀 Sistem başlatılıyor.");
    try {
      newOrderNotificationDataNotifier.addListener(_handleNewNotification);
      _isInitialized = true;
    } catch (e) {
      debugPrint("[GlobalNotificationHandler] initialize addListener hata: $e");
    }
  }

  static void _handleNewNotification() {
    if (!_isInitialized) return;
    final data = newOrderNotificationDataNotifier.value;
    if (data == null) return;
    try {
      newOrderNotificationDataNotifier.value = null;
    } catch (e) {
      debugPrint("[GlobalNotificationHandler] _handleNewNotification notifier reset hatası: $e");
    }
    if (_instance == null || _instance!._isDisposed) {
      debugPrint("[GlobalNotificationHandler] _handleNewNotification: instance yok veya disposed, atlanıyor.");
      return;
    }
    _instance!._addToQueue(data);
  }

  void addNotification(Map<String, dynamic> data) {
    if (_isDisposed) {
      debugPrint('[GlobalNotificationHandler] addNotification çağrıldı ancak instance disposed, atlanıyor: ${data['event_type']}');
      return;
    }
    debugPrint('[GlobalNotificationHandler] 📨 Direct notification added: ${data['event_type']}');
    _addToQueue(data);
  }

  void _addToQueue(Map<String, dynamic> data) {
    if (_isDisposed) {
      debugPrint('[GlobalNotificationHandler] _addToQueue atlandı (disposed): ${data['event_type']}');
      return;
    }
    final eventType = data['event_type'] as String?;
    final notificationId = data['notification_id'] as String? ??
        '${eventType}_${DateTime.now().millisecondsSinceEpoch}';
    if (_processedBannerIds.contains(notificationId)) {
      debugPrint('📨 [GlobalNotificationHandler] Banner duplicate engellendi: $notificationId');
      return;
    }
    _processedBannerIds.add(notificationId);
    if (_processedBannerIds.length > 50) {
      _processedBannerIds.remove(_processedBannerIds.first);
    }
    _notificationQueue.add(data);
    debugPrint('[GlobalNotificationHandler] Kuyruğa eklendi: $eventType. Kuyruk boyutu: ${_notificationQueue.length}');
    _processQueue();
  }

  void processPendingNotifications() {
    if (_isDisposed) {
      debugPrint('[GlobalNotificationHandler] processPendingNotifications atlandı (disposed).');
      return;
    }
    debugPrint("[GlobalNotificationHandler] Bekleyen bildirimler işleniyor...");
    _processQueue();
  }

  void _processQueue() async {
    if (_isDisposed) {
      debugPrint('[GlobalNotificationHandler] _processQueue atlandı (disposed).');
      return;
    }
    if (_isProcessing || _notificationQueue.isEmpty || _isBannerShowing) {
      return;
    }
    if (!_isAppInForeground || !NavigatorSafeZone.canNavigate()) {
      debugPrint('[GlobalNotificationHandler] Uygulama hazır değil (Foreground: $_isAppInForeground, Navigator Safe: ${NavigatorSafeZone.canNavigate()}), kuyruk bekliyor.');
      return;
    }
    _isProcessing = true;
    try {
      while (!_isDisposed &&
          _notificationQueue.isNotEmpty &&
          _isAppInForeground &&
          !_isBannerShowing &&
          NavigatorSafeZone.canNavigate()) {
        final notification = _notificationQueue.removeFirst();
        await _processNotification(notification);
        _scheduleGlobalRefresh(notification['event_type'] ?? '', notification);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e, s) {
      debugPrint('[GlobalNotificationHandler] ❌ Kuyruk işleme hatası: $e');
      debugPrintStack(stackTrace: s);
    } finally {
      _isProcessing = false;
    }
  }

  static void _scheduleGlobalRefresh(
      String eventType, Map<String, dynamic> data) {
    if (_instance == null || _instance!._isDisposed) {
      debugPrint("[GlobalNotificationHandler] _scheduleGlobalRefresh atlandı (disposed).");
      return;
    }

    _pendingRefreshes.add(eventType);
    
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (_pendingRefreshes.isNotEmpty) {
        debugPrint("[GlobalNotificationHandler] 📡 Toplu yenileme tetikleniyor: ${_pendingRefreshes.join(', ')}");
        
        NotificationCenter.instance.postNotification('refresh_all_screens', {
          'eventTypes': _pendingRefreshes.toList(),
          'batchRefresh': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch
        });
        
        _pendingRefreshes.clear();
      }
    });
  }

  Future<void> _processNotification(Map<String, dynamic> notification) async {
    try {
      if (_isDisposed) {
        debugPrint('[GlobalNotificationHandler] _processNotification atlandı (disposed).');
        return;
      }
      final eventType = notification['event_type'] as String?;
      final orderId = notification['order_id'];
      if (eventType == null || !UserSession.hasNotificationPermission(eventType)) {
        debugPrint('[GlobalNotificationHandler] Yetki yok veya event tipi belirsiz: $eventType');
        return;
      }
      
      final bool requiresDialog = [
        NotificationEventTypes.orderApprovedForKitchen,
        'order_approved_for_kitchen',
        NotificationEventTypes.orderReadyForPickupUpdate,
        'order_ready_for_pickup_update'
      ].contains(eventType);

      if (requiresDialog) {
        debugPrint('[GlobalNotificationHandler] 🎯 Dialog gösteriliyor: $eventType (Order: $orderId)');
        await _showNotificationDialog(eventType, notification);
      } else {
        debugPrint('[GlobalNotificationHandler] 🎯 Banner gösteriliyor: $eventType (Order: $orderId)');
        await _showBanner(eventType, notification);
      }

    } catch (e, s) {
      debugPrint('[GlobalNotificationHandler] ❌ BİLDİRİM İŞLEME HATASI YAKALANDI: $e');
      debugPrint('[GlobalNotificationHandler] Stack Trace: $s');
      if (_isBannerShowing) {
          _cleanupBanner();
      }
    }
  }
  
  // HATA DÜZELTME: Bu metot artık `GlobalNotificationHandler` içinde.
  bool _shouldShowDialog() {
    return _isAppInForeground && !_isBannerShowing && !_isDialogShowing && NavigatorSafeZone.canNavigate();
  }

  Future<void> _showNotificationDialog(String eventType, Map<String, dynamic> data) async {
    if (!_shouldShowDialog()) return;
    
    final context = navigatorKey.currentContext;
    if (context == null) return;
    
    Widget? dialogWidget;
    switch (eventType) {
      case NotificationEventTypes.orderApprovedForKitchen:
      case 'order_approved_for_kitchen':
        // HATA DÜZELTME: Diyaloglar 'notificationData' bekliyor, 'order' değil.
        dialogWidget = OrderApprovedForKitchenDialog(notificationData: data, onAcknowledge: () {});
        break;
      case NotificationEventTypes.orderReadyForPickupUpdate:
      case 'order_ready_for_pickup_update':
        // HATA DÜZELTME: Diyaloglar 'notificationData' bekliyor, 'order' değil.
        dialogWidget = OrderReadyForPickupDialog(notificationData: data, onAcknowledge: () {});
        break;
    }
    
    if (dialogWidget != null && !_isDisposed) {
      _isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => dialogWidget!,
      ).then((_) {
        if (!_isDisposed) {
          _isDialogShowing = false;
          shouldRefreshTablesNotifier.value = true;
          _processQueue();
        }
      });
    }
  }

  Future<void> _showBanner(
      String eventType, Map<String, dynamic> data) async {
    if (_isDisposed) {
      debugPrint('[GlobalNotificationHandler] _showBanner atlandı (disposed).');
      return;
    }
    final context = navigatorKey.currentContext;
    if (context == null || _isBannerShowing || !NavigatorSafeZone.canNavigate()) {
      debugPrint('[GlobalNotificationHandler] ❌ Banner gösterilemedi (Context null, meşgul veya güvenli değil).');
      if (!_isDisposed) {
        _notificationQueue.addFirst(data);
      }
      return;
    }
    
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      debugPrint('[GlobalNotificationHandler] ❌ Banner gösterilemedi (l10n is null).');
      if (!_isDisposed) {
        _notificationQueue.addFirst(data);
      }
      return;
    }

    NavigatorSafeZone.setNavigating(true);
    _isBannerShowing = true;
    _bannerTimedOut = false;
    
    try {
      _playNotificationSound(eventType);
    } catch (e) {
      debugPrint("Ses çalma hatası banner akışını etkilemedi: $e");
    }

    final message = _getNotificationMessage(l10n, eventType, data);
    final duration = _bannerDurations[eventType] ?? _defaultBannerDuration;

    final completer = Completer<void>();
    _bannerTimeoutTimer?.cancel();
    _bannerTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (_isBannerShowing && !_bannerTimedOut) {
        debugPrint('[GlobalNotificationHandler] ⏰ BANNER ZAMAN AŞIMI - Zorla temizleniyor');
        _bannerTimedOut = true;
        _cleanupBanner();
        
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    try {
      await Flushbar(
        messageText: Text(
          message,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        icon: Icon(
          NotificationUiHelper.getIconForNotificationType(eventType),
          color: NotificationUiHelper.getIconColorForNotificationType(eventType),
          size: 32,
        ),
        duration: duration,
        flushbarPosition: FlushbarPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(12),
        backgroundColor: _getBackgroundColorForEvent(eventType),
        boxShadows: const [
          BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 5))
        ],
        onStatusChanged: (status) {
          if (status == FlushbarStatus.DISMISSED && !_bannerTimedOut) {
            debugPrint("[GlobalNotificationHandler] ✅ Banner normal şekilde kapatıldı.");
            _cleanupBanner();
            if (!completer.isCompleted) {
              completer.complete();
            }
          }
        },
      ).show(context);
    } catch (e) {
      debugPrint('[GlobalNotificationHandler] ❌ Banner gösterme hatası: $e');
      _cleanupBanner();
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  void _cleanupBanner() {
    _bannerTimeoutTimer?.cancel();
    _isBannerShowing = false;
    NavigatorSafeZone.setNavigating(false);
    
    debugPrint("[GlobalNotificationHandler] ✅ Banner temizlendi - Navigasyon serbest.");
    Timer(const Duration(milliseconds: 100), () {
      if (!_isDisposed) {
        _processQueue();
      }
    });
  }

  Color _getBackgroundColorForEvent(String eventType) {
    switch (eventType) {
      case NotificationEventTypes.orderApprovedForKitchen:
      case 'order_approved_for_kitchen':
        return Colors.green.shade700.withOpacity(0.95);
      case NotificationEventTypes.orderReadyForPickupUpdate:
      case 'order_ready_for_pickup_update':
        return Colors.orange.shade700.withOpacity(0.95);
      case NotificationEventTypes.orderItemAdded:
        return Colors.blue.shade700.withOpacity(0.95);
      case NotificationEventTypes.orderPreparingUpdate:
      case 'order_preparing_update':
        return Colors.amber.shade700.withOpacity(0.95);
      case 'order_pending_approval':
      case 'new_order_notification':
        return Colors.purple.shade700.withOpacity(0.95);
      default:
        return Colors.blueGrey.shade800.withOpacity(0.95);
    }
  }

  String _getNotificationMessage(AppLocalizations l10n, String eventType, Map<String, dynamic> data) {
    final orderData = data['updated_order_data'] as Map<String, dynamic>? ?? data;
    final orderId = orderData['id']?.toString() ?? '';
    
    final tableNumber = orderData['table_number']?.toString();
    final tableInfo = tableNumber != null ? l10n.notificationTableInfo(tableNumber) : '';
    
    final displayNames = NotificationEventTypes.getDisplayNames(l10n);

    if (data['message'] is String && (data['message'] as String).isNotEmpty) {
      return data['message'];
    }

    switch (eventType) {
      case NotificationEventTypes.orderApprovedForKitchen:
        return l10n.notificationOrderApprovedForKitchen(orderId, tableInfo);
      case NotificationEventTypes.orderPreparingUpdate:
        return l10n.notificationOrderPreparing(orderId) + tableInfo;
      case NotificationEventTypes.orderReadyForPickupUpdate:
        return l10n.notificationOrderReadyForPickup(orderId) + tableInfo;
      case NotificationEventTypes.orderItemAdded:
        return l10n.notificationOrderItemAdded(orderId);
      case NotificationEventTypes.guestOrderPendingApproval:
        return l10n.notificationGuestOrderPending(orderId) + tableInfo;
      case NotificationEventTypes.existingOrderNeedsReapproval:
        return l10n.notificationOrderNeedsReapproval(orderId) + tableInfo;
      case 'new_order_notification': // Fallback
        return l10n.notificationNewOrder(orderId, tableInfo);
      default:
        return displayNames[eventType] ?? l10n.notificationDefault;
    }
  }

  // ==================== GÜNCELLENMİŞ METOT BAŞLANGICI ====================
  void _playNotificationSound(String eventType) async {
    if (_isDisposed) return;
    if (_isSoundPlaying || kIsWeb) return;
    if (!_shouldPlaySound(eventType)) return;
    
    _isSoundPlaying = true;
    debugPrint('🔔 [GlobalNotificationHandler] Bildirim sesi çalınıyor: $eventType');

    // 1. Olay tipine göre çalınacak ses dosyasının temel adını belirle
    String? soundFilename;
    switch (eventType) {
      case NotificationEventTypes.guestOrderPendingApproval:
      case NotificationEventTypes.existingOrderNeedsReapproval:
      case 'new_order_notification':
        soundFilename = 'new_order.mp3';
        break;

      case NotificationEventTypes.orderApprovedForKitchen:
        soundFilename = 'order_confirmed.mp3';
        break;
      case NotificationEventTypes.orderPreparingUpdate:
        soundFilename = 'order_preparing.mp3';
        break;

      case NotificationEventTypes.orderReadyForPickupUpdate:
        soundFilename = 'order_ready.mp3';
        break;
    }

    if (soundFilename != null) {
      // 2. LanguageProvider'dan mevcut dil kodunu al
      final langCode = LanguageProvider.currentLanguageCode;
      final soundPath = 'sounds/notifications/$langCode/$soundFilename';
      final fallbackPath = 'sounds/notifications/tr/$soundFilename';

      try {
        debugPrint('🔔 [GlobalNotificationHandler] Denenen ses yolu: $soundPath');
        await _audioPlayer.play(AssetSource(soundPath));
      } catch (e) {
        debugPrint("❌ [GlobalNotificationHandler] Özel dil sesi ($soundPath) çalınırken hata: $e. Varsayılan dil deneniyor.");
        // Hata durumunda varsayılan Türkçe sesi çalmayı dene
        try {
          debugPrint('🔔 [GlobalNotificationHandler] Varsayılan ses yolu deneniyor: $fallbackPath');
          await _audioPlayer.play(AssetSource(fallbackPath));
        } catch (fallbackError) {
          debugPrint("❌ [GlobalNotificationHandler] Varsayılan bildirim sesi de çalınamadı: $fallbackError");
        }
      }
    }

    // Cooldown'ı başlat
    _soundCooldownTimer?.cancel();
    _soundCooldownTimer = Timer(_soundCooldown, () {
      _isSoundPlaying = false;
      debugPrint('[GlobalNotificationHandler] Ses cooldown sona erdi');
    });
  }
  // ==================== GÜNCELLENMİŞ METOT SONU ====================

  bool _shouldPlaySound(String eventType) {
    final soundEvents = <String>{
      NotificationEventTypes.guestOrderPendingApproval,
      NotificationEventTypes.existingOrderNeedsReapproval,
      NotificationEventTypes.orderApprovedForKitchen,
      NotificationEventTypes.orderReadyForPickupUpdate,
      NotificationEventTypes.orderItemAdded,
      NotificationEventTypes.orderPreparingUpdate,
      'order_approved_for_kitchen',
      'order_ready_for_pickup_update',
      'order_preparing_update',
      'order_pending_approval',
      'new_order_notification',
    };
    return soundEvents.contains(eventType);
  }

  bool _isCriticalEvent(String eventType) {
    final criticalEvents = <String>{
      NotificationEventTypes.orderApprovedForKitchen,
      NotificationEventTypes.orderReadyForPickupUpdate,
      NotificationEventTypes.guestOrderPendingApproval,
      NotificationEventTypes.existingOrderNeedsReapproval,
      'order_approved_for_kitchen',
      'order_ready_for_pickup_update',
      'order_pending_approval',
      'new_order_notification',
    };
    return criticalEvents.contains(eventType);
  }

  void dispose() {
    if (_isDisposed) {
      debugPrint("[GlobalNotificationHandler] dispose() zaten çağrılmış, atlanıyor.");
      return;
    }
    debugPrint("[GlobalNotificationHandler] Disposing instance...");

    _isDisposed = true;

    try {
      _soundCooldownTimer?.cancel();
    } catch (e) {
      debugPrint("[GlobalNotificationHandler] soundCooldownTimer cancel hatası: $e");
    }
    try {
      _bannerTimeoutTimer?.cancel();
    } catch (e) {
      debugPrint("[GlobalNotificationHandler] bannerTimeoutTimer cancel hatası: $e");
    }
    try {
      _refreshDebounceTimer?.cancel();
      _refreshDebounceTimer = null;
      _pendingRefreshes.clear();
    } catch (e) {
      debugPrint("[GlobalNotificationHandler] refreshTimer cancel hatası: $e");
    }

    try {
      _notificationQueue.clear();
      _processedBannerIds.clear();
    } catch (e) {
      debugPrint("[GlobalNotificationHandler] queue clear hatası: $e");
    }

    try {
      if (_isInitialized) {
        newOrderNotificationDataNotifier.removeListener(_handleNewNotification);
        _isInitialized = false;
        debugPrint("[GlobalNotificationHandler] newOrderNotificationDataNotifier listener kaldırıldı.");
      }
    } catch (e) {
      debugPrint("[GlobalNotificationHandler] dispose removeListener hatası: $e");
    }

    debugPrint("[GlobalNotificationHandler] Instance disposed.");
  }
}
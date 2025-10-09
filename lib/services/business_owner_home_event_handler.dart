// lib/services/business_owner_home_event_handler.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/notification_center.dart';
import '../services/socket_service.dart';
import '../services/connectivity_service.dart';
import '../services/user_session.dart';
import '../services/order_service.dart';
import '../services/kds_service.dart';
import '../services/ingredient_service.dart';
import '../models/notification_event_types.dart';
import '../models/kds_screen_model.dart';
import '../utils/notifiers.dart';

class BusinessOwnerHomeEventHandler {
  static BusinessOwnerHomeEventHandler? _instance;
  static BusinessOwnerHomeEventHandler get instance {
    _instance ??= BusinessOwnerHomeEventHandler._internal();
    return _instance!;
  }
  
  BusinessOwnerHomeEventHandler._internal();

  final SocketService _socketService = SocketService.instance;
  final ConnectivityService _connectivityService = ConnectivityService.instance;
  
  // Event handling state
  static final Map<String, Timer> _eventThrottlers = {};
  static final Set<String> _processingEvents = {};
  static Timer? _batchEventTimer;
  static final Set<String> _pendingEventTypes = {};
  
  // Callback functions - Initialize edilmemiş late değişkenlerin yerine nullable yaptık
  Function()? _onOrderCountRefresh;
  Function()? _onStockAlertsCheck;
  Function()? _onConnectivityChanged;
  Function()? _onSocketStatusUpdate;
  Function()? _onSyncStatusMessage;
  Function()? _onStockAlertUpdate;
  bool Function()? _shouldProcessUpdate; // DÜZELTME: nullable yapıldı ve default değer eklendi
  
  // Notification callbacks - Aynı şekilde nullable yapıldı
  Function(Map<String, dynamic>)? _refreshAllScreensCallback;
  Function(Map<String, dynamic>)? _screenBecameActiveCallback;
  Function(Map<String, dynamic>)? _kdsUpdateCallback;
  
  bool _isInitialized = false;
  String _token = '';
  int _businessId = 0;
  List<KdsScreenModel> _availableKdsScreens = [];
  
  void initialize({
    required String token,
    required int businessId,
    required List<KdsScreenModel> availableKdsScreens,
    required Function() onOrderCountRefresh,
    required Function() onStockAlertsCheck,
    required Function() onConnectivityChanged,
    required Function() onSocketStatusUpdate,
    required Function() onSyncStatusMessage,
    required Function() onStockAlertUpdate,
    required bool Function() shouldProcessUpdate,
  }) {
    if (_isInitialized) return;
    
    _token = token;
    _businessId = businessId;
    _availableKdsScreens = availableKdsScreens;
    _onOrderCountRefresh = onOrderCountRefresh;
    _onStockAlertsCheck = onStockAlertsCheck;
    _onConnectivityChanged = onConnectivityChanged;
    _onSocketStatusUpdate = onSocketStatusUpdate;
    _onSyncStatusMessage = onSyncStatusMessage;
    _onStockAlertUpdate = onStockAlertUpdate;
    _shouldProcessUpdate = shouldProcessUpdate;
    
    _setupNotificationCenterListeners();
    _addSocketServiceAndNotifierListeners();
    
    _isInitialized = true;
    debugPrint("[BusinessOwnerHomeEventHandler] Handler initialized successfully");
  }
  
  void updateAvailableKdsScreens(List<KdsScreenModel> screens) {
    _availableKdsScreens = screens;
  }
  
  void dispose() {
    if (!_isInitialized) return;
    
    _cleanupNotificationCenterListeners();
    _removeSocketServiceAndNotifierListeners();
    
    _eventThrottlers.values.forEach((timer) => timer.cancel());
    _eventThrottlers.clear();
    _batchEventTimer?.cancel();
    _processingEvents.clear();
    _pendingEventTypes.clear();
    
    _isInitialized = false;
    debugPrint("[BusinessOwnerHomeEventHandler] Handler disposed");
  }

  // Helper method to safely check if updates should be processed
  bool _canProcessUpdate() {
    return _shouldProcessUpdate?.call() ?? false;
  }

  void _setupNotificationCenterListeners() {
    _refreshAllScreensCallback = (data) {
      if (!_canProcessUpdate()) return;
      final eventType = data['eventType'] as String?;
      final eventData = data['data'] as Map<String, dynamic>?;
      
      if (data['batchRefresh'] == true) {
        final eventTypes = data['eventTypes'] as List<String>? ?? [];
        debugPrint("[BusinessOwnerHomeEventHandler] 📡 Batch refresh received: ${eventTypes.join(', ')}");
        
        bool shouldRefresh = eventTypes.any((type) => _shouldRefreshForEvent(type));
        if (shouldRefresh) {
          _throttledEventProcessor('batch_refresh', () async {
            await _onOrderCountRefresh?.call();
            await _onStockAlertsCheck?.call();
          });
        }
        return;
      }
      
      debugPrint("[BusinessOwnerHomeEventHandler] 📡 Global refresh received: $eventType");
      if (_shouldRefreshForEvent(eventType)) {
        _throttledEventProcessor('global_refresh_$eventType', () async {
          await _onOrderCountRefresh?.call();
          await _onStockAlertsCheck?.call();
        });
      }
    };

    _screenBecameActiveCallback = (data) {
      if (!_canProcessUpdate()) return;
      debugPrint("[BusinessOwnerHomeEventHandler] 📱 Screen became active notification received");
      _throttledEventProcessor('screen_active', () async {
        await _onOrderCountRefresh?.call();
        await _onStockAlertsCheck?.call();
      });
    };

    _kdsUpdateCallback = (data) {
      if (!_canProcessUpdate()) return;
      final eventType = data['event_type'] as String?;
      debugPrint("[BusinessOwnerHomeEventHandler] 🔥 KDS update detected: $eventType");
      if (_isKdsEvent(eventType)) {
        _immediateEventProcessor('kds_update_$eventType', () async {
          await _onOrderCountRefresh?.call();
          await _onStockAlertsCheck?.call();
        });
      }
    };

    if (_refreshAllScreensCallback != null) {
      NotificationCenter.instance.addObserver('refresh_all_screens', _refreshAllScreensCallback!);
    }
    if (_screenBecameActiveCallback != null) {
      NotificationCenter.instance.addObserver('screen_became_active', _screenBecameActiveCallback!);
    }
    if (_kdsUpdateCallback != null) {
      NotificationCenter.instance.addObserver('order_status_update', _kdsUpdateCallback!);
    }
  }

  void _cleanupNotificationCenterListeners() {
    if (_refreshAllScreensCallback != null) {
      NotificationCenter.instance.removeObserver('refresh_all_screens', _refreshAllScreensCallback!);
    }
    if (_screenBecameActiveCallback != null) {
      NotificationCenter.instance.removeObserver('screen_became_active', _screenBecameActiveCallback!);
    }
    if (_kdsUpdateCallback != null) {
      NotificationCenter.instance.removeObserver('order_status_update', _kdsUpdateCallback!);
    }
  }

  void _addSocketServiceAndNotifierListeners() {
    _connectivityService.isOnlineNotifier.addListener(_onConnectivityChanged ?? () {});
    _socketService.connectionStatusNotifier.addListener(_onSocketStatusUpdate ?? () {});
    orderStatusUpdateNotifier.addListener(_handleSilentOrderUpdatesThrottled);
    shouldRefreshWaitingCountNotifier.addListener(_handleWaitingCountRefreshThrottled);
    shouldRefreshTablesNotifier.addListener(_handleTablesRefreshThrottled);
    syncStatusMessageNotifier.addListener(_onSyncStatusMessage ?? () {});
    stockAlertNotifier.addListener(_onStockAlertUpdate ?? () {});
    debugPrint("[BusinessOwnerHomeEventHandler] Notifier listener'ları eklendi.");
  }

  void _removeSocketServiceAndNotifierListeners() {
    _connectivityService.isOnlineNotifier.removeListener(_onConnectivityChanged ?? () {});
    _socketService.connectionStatusNotifier.removeListener(_onSocketStatusUpdate ?? () {});
    orderStatusUpdateNotifier.removeListener(_handleSilentOrderUpdatesThrottled);
    shouldRefreshWaitingCountNotifier.removeListener(_handleWaitingCountRefreshThrottled);
    shouldRefreshTablesNotifier.removeListener(_handleTablesRefreshThrottled);
    syncStatusMessageNotifier.removeListener(_onSyncStatusMessage ?? () {});
    stockAlertNotifier.removeListener(_onStockAlertUpdate ?? () {});
    debugPrint("[BusinessOwnerHomeEventHandler] Tüm notifier listener'ları kaldırıldı.");
  }

  void _throttledEventProcessor(String eventKey, Future<void> Function() processor) {
    if (_processingEvents.contains(eventKey)) {
      debugPrint("[BusinessOwnerHomeEventHandler] 🚫 Event $eventKey already processing, skipping...");
      return;
    }

    _eventThrottlers[eventKey]?.cancel();
    if (eventKey.contains('order_cancelled') || 
        eventKey.contains('order_completed') || 
        eventKey.contains('critical_order') ||
        eventKey.contains('pickup_delivery') ||
        eventKey.contains('order_item_picked_up') ||
        eventKey.contains('order_item_delivered') ||
        eventKey.contains('order_picked_up_by_waiter')) {
      debugPrint("[BusinessOwnerHomeEventHandler] 🔥 Critical event detected, using immediate processing: $eventKey");
      _immediateEventProcessor(eventKey, processor);
      return;
    }
    
    _eventThrottlers[eventKey] = Timer(const Duration(milliseconds: 300), () async {
      if (!_canProcessUpdate()) return;
      
      _processingEvents.add(eventKey);
      debugPrint("[BusinessOwnerHomeEventHandler] 🟡 Processing throttled event: $eventKey");
      
      try {
        await processor();
        debugPrint("[BusinessOwnerHomeEventHandler] ✅ Completed throttled event: $eventKey");
      } catch (e) {
        debugPrint("[BusinessOwnerHomeEventHandler] ❌ Error in throttled event $eventKey: $e");
      } finally {
        _processingEvents.remove(eventKey);
        _eventThrottlers.remove(eventKey);
      }
    });
    debugPrint("[BusinessOwnerHomeEventHandler] ⏱️ Throttled event scheduled: $eventKey (300ms delay)");
  }

  void _immediateEventProcessor(String eventKey, Future<void> Function() processor) {
    if (_processingEvents.contains(eventKey)) {
      debugPrint("[BusinessOwnerHomeEventHandler] 🚫 Critical event $eventKey already processing, skipping...");
      return;
    }

    _processingEvents.add(eventKey);
    debugPrint("[BusinessOwnerHomeEventHandler] 🔥 Processing immediate event: $eventKey");
    processor().then((_) {
      debugPrint("[BusinessOwnerHomeEventHandler] ✅ Completed immediate event: $eventKey");
    }).catchError((e) {
      debugPrint("[BusinessOwnerHomeEventHandler] ❌ Error in immediate event $eventKey: $e");
    }).whenComplete(() {
      _processingEvents.remove(eventKey);
    });
  }

  void _handleTablesRefreshThrottled() {
    if (!_canProcessUpdate()) {
      debugPrint('[BusinessOwnerHomeEventHandler] Ekran aktif değil, tables refresh atlandı.');
      return;
    }
    
    _throttledEventProcessor('tables_refresh', () async {
      debugPrint('[BusinessOwnerHomeEventHandler] Enhanced notification tables refresh tetiklendi');
      await _onOrderCountRefresh?.call();
      await _onStockAlertsCheck?.call();
    });
  }

  void _handleWaitingCountRefreshThrottled() {
    if (!_canProcessUpdate()) {
      debugPrint('[BusinessOwnerHomeEventHandler] Ekran aktif değil, waiting count refresh atlandı.');
      return;
    }
    
    _throttledEventProcessor('waiting_count_refresh', () async {
      debugPrint('[BusinessOwnerHomeEventHandler] Waiting count refresh tetiklendi');
      await _onOrderCountRefresh?.call();
    });
  }

  void _handleSilentOrderUpdatesThrottled() {
    final notificationData = orderStatusUpdateNotifier.value;
    if (notificationData == null || !_canProcessUpdate()) {
      if (notificationData != null) {
        debugPrint("[BusinessOwnerHomeEventHandler] Ekran aktif değil, bildirim atlandı: ${notificationData['event_type']}");
      }
      return;
    }
    
    final eventType = notificationData['event_type'] as String?;
    debugPrint("[BusinessOwnerHomeEventHandler] Anlık güncelleme alındı: $eventType");
    
    if (eventType == 'order_item_picked_up' || 
        eventType == 'order_item_delivered' ||
        eventType == 'order_picked_up_by_waiter' ||
        _isPickupDeliveryEvent(eventType)) {
      debugPrint("[BusinessOwnerHomeEventHandler] 🔥 Item pickup/delivery event detected, using immediate processing: $eventType");
      _immediateEventProcessor('pickup_delivery_$eventType', () async {
        await _onOrderCountRefresh?.call();
        await _onStockAlertsCheck?.call();
      });
      return;
    }
    
    if (eventType == 'order_cancelled_update' || eventType == 'order_completed_update') {
      debugPrint("[BusinessOwnerHomeEventHandler] 🔥 Critical order event detected, using priority refresh: $eventType");
      _immediateEventProcessor('critical_order_$eventType', () async {
        await _onOrderCountRefresh?.call();
        await _onStockAlertsCheck?.call();
      });
      return;
    }
    
    if (_isKdsEvent(eventType)) {
      debugPrint("[BusinessOwnerHomeEventHandler] 🔥 KDS event detected, using priority refresh: $eventType");
      _immediateEventProcessor('kds_direct_$eventType', () async {
        await _onOrderCountRefresh?.call();
        await _onStockAlertsCheck?.call();
      });
      return;
    }
    
    if (_shouldRefreshForEvent(eventType) || notificationData['is_paid_update'] == true) {
      _throttledEventProcessor('order_update_$eventType', () async {
        debugPrint("[BusinessOwnerHomeEventHandler] Sayaçları etkileyen bir olay geldi, sayılar yenileniyor.");
        await _onOrderCountRefresh?.call();
        await _onStockAlertsCheck?.call();
      });
    } else {
      debugPrint("[BusinessOwnerHomeEventHandler] Sayaçları etkilemeyen olay, atlandı: $eventType");
    }
  }

  bool _isKdsEvent(String? eventType) {
    if (eventType == null) return false;
    const kdsEvents = {
      'order_preparing_update',
      'order_ready_for_pickup_update',
      'order_item_picked_up',
      'order_fully_delivered',
      'order_picked_up_by_waiter',
      'order_item_delivered',
    };
    return kdsEvents.contains(eventType) ||
           eventType.contains('preparing') || 
           eventType.contains('ready_for_pickup') ||
           eventType.contains('picked_up') ||
           eventType.contains('delivered');
  }

  bool _shouldRefreshForEvent(String? eventType) {
    if (eventType == null) return false;
    const countAffectingEvents = {
      NotificationEventTypes.guestOrderPendingApproval,
      NotificationEventTypes.orderCancelledUpdate,
      NotificationEventTypes.orderApprovedForKitchen,
      NotificationEventTypes.orderPreparingUpdate,
      NotificationEventTypes.orderReadyForPickupUpdate,
      NotificationEventTypes.orderCompletedUpdate,
      NotificationEventTypes.orderItemAdded,
      NotificationEventTypes.orderItemRemoved,
      'order_item_picked_up',
      'order_item_delivered',
      'order_picked_up_by_waiter',
    };
    return countAffectingEvents.contains(eventType) ||
           eventType.contains('picked_up') ||
           eventType.contains('delivered');
  }

  bool _isPickupDeliveryEvent(String? eventType) {
    if (eventType == null) return false;
    const pickupDeliveryEvents = {
      'order_item_picked_up',
      'order_item_delivered',
      'order_picked_up_by_waiter',
      'waiter_pickup_update',
      'delivery_status_update',
    };
    return pickupDeliveryEvents.contains(eventType) ||
           eventType.contains('picked_up') ||
           eventType.contains('delivery') ||
           eventType.contains('waiter');
  }

  // Public methods for external access
  void safeRefreshDataWithThrottling() {
    if (!_canProcessUpdate()) return;
    _throttledEventProcessor('business_owner_home_refresh', () async {
      await _onOrderCountRefresh?.call();
      await _onStockAlertsCheck?.call();
    });
  }

  void handleScreenBecameActive() {
    if (!_canProcessUpdate()) return;
    _throttledEventProcessor('screen_active', () async {
      await _onOrderCountRefresh?.call();
      await _onStockAlertsCheck?.call();
    });
  }
}
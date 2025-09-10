// lib/screens/business_owner_home.dart
// Enhanced socket connection with network state tracking and multiple retry strategy

import '../services/notification_center.dart';
import '../services/refresh_manager.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:makarna_app/services/stock_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';
// Servisler
import '../services/user_session.dart';
import '../services/socket_service.dart';
import '../services/order_service.dart';
import '../services/kds_service.dart';
import '../services/kds_management_service.dart';
import '../services/connectivity_service.dart';
import '../services/global_notification_handler.dart' as globalHandler;
import '../services/connection_manager.dart';
import '../services/api_service.dart';
// Modeller
import '../models/kds_screen_model.dart';
import '../models/notification_event_types.dart';
import '../models/staff_permission_keys.dart';
// +++ YENİ: Vardiya modeli için import eklendi +++
import '../models/scheduled_shift_model.dart';
// Ekranlar
import 'create_order_screen.dart';
import 'takeaway_order_screen.dart';
import 'kds_screen.dart';
import 'notification_screen.dart';
import 'manage_kds_screens_screen.dart';
import 'login_screen.dart';
// Widget'lar
import '../widgets/home/business_owner_home_content.dart';
import '../widgets/home/user_profile_avatar.dart';
import '../widgets/shared/offline_banner.dart';
import '../widgets/shared/sync_status_indicator.dart';
// Diğerleri
import '../utils/notifiers.dart';
import '../main.dart';

class BusinessOwnerHome extends StatefulWidget {
    final String token;
    final int businessId;
    const BusinessOwnerHome(
        {Key? key, required this.token, required this.businessId})
        : super(key: key);
    @override
    _BusinessOwnerHomeState createState() => _BusinessOwnerHomeState();
}

class _BusinessOwnerHomeState extends State<BusinessOwnerHome>
    with RouteAware, WidgetsBindingObserver {
    
    int _currentIndex = 0;
    bool _isInitialLoadComplete = false;
    
    // Screen state tracking
    bool _isCurrent = true;
    bool _isAppInForeground = true;
    List<Widget> _activeTabPages = [];
    List<BottomNavigationBarItem> _activeNavBarItems = [];

    final SocketService _socketService = SocketService.instance;
    final ConnectivityService _connectivityService = ConnectivityService.instance;
    final ValueNotifier<int> _activeTableOrderCountNotifier = ValueNotifier(0);
    final ValueNotifier<int> _activeTakeawayOrderCountNotifier = ValueNotifier(0);
    final ValueNotifier<int> _activeKdsOrderCountNotifier = ValueNotifier(0);

    Timer? _orderCountRefreshTimer;
    DateTime? _lastRefreshTime;
    List<KdsScreenModel> _availableKdsScreensForUser = [];
    bool _isLoadingKdsScreens = true;
    String? _currentKdsRoomSlugForSocketService;
    
    bool _hasStockAlerts = false;
    static final Map<String, Timer> _eventThrottlers = {};
    static final Set<String> _processingEvents = {};
    static Timer? _batchEventTimer;
    static final Set<String> _pendingEventTypes = {};
    late Function(Map<String, dynamic>) _refreshAllScreensCallback;
    late Function(Map<String, dynamic>) _screenBecameActiveCallback;
    late Function(Map<String, dynamic>) _kdsUpdateCallback;

    // +++++++++++++++++++++ YENİ EKLENEN BÖLÜM BAŞLANGICI (Vardiya Sayacı) +++++++++++++++++++++
    Timer? _shiftEndTimer;
    String? _shiftCountdownText; // Geri sayım metnini tutacak
    ScheduledShift? _activeShift; // Aktif vardiya modelini tutacak
    // +++++++++++++++++++++ YENİ EKLENEN BÖLÜM SONU (Vardiya Sayacı) +++++++++++++++++++++

    @override
    void initState() {
        super.initState();
        debugPrint("[${DateTime.now()}] _BusinessOwnerHomeState: initState. User: ${UserSession.username}, Type: ${UserSession.userType}");
        
        WidgetsBinding.instance.addObserver(this);
        _setupNotificationCenterListeners();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
                // 🔧 FIX 4: Socket bağlantısını async olarak başlat
                _initializeAsyncDependencies();
            }
        });
        _addSocketServiceAndNotifierListeners();
    }

    @override
    void dispose() {
        debugPrint("[${DateTime.now()}] _BusinessOwnerHomeState: dispose.");
        routeObserver.unsubscribe(this);
        WidgetsBinding.instance.removeObserver(this);
        
        _cleanupNotificationCenterListeners();
        _removeSocketServiceAndNotifierListeners();
        _orderCountRefreshTimer?.cancel();
        
        // +++++++++++++++++++++ YENİ EKLENEN BÖLÜM BAŞLANGICI (Vardiya Sayacı) +++++++++++++++++++++
        _shiftEndTimer?.cancel();
        // +++++++++++++++++++++ YENİ EKLENEN BÖLÜM SONU (Vardiya Sayacı) +++++++++++++++++++++

        _eventThrottlers.values.forEach((timer) => timer.cancel());
        _eventThrottlers.clear();
        _batchEventTimer?.cancel();
        _processingEvents.clear();
        _pendingEventTypes.clear();
        
        _activeTableOrderCountNotifier.dispose();
        _activeTakeawayOrderCountNotifier.dispose();
        _activeKdsOrderCountNotifier.dispose();
        
        super.dispose();
    }

    // +++++++++++++++++++++ YENİ EKLENEN METOTLAR BAŞLANGICI (Vardiya Sayacı) +++++++++++++++++++++
    /// Personelin aktif vardiyasını çeker ve geri sayım sayacını başlatır.
    Future<void> _fetchAndMonitorShift() async {
      if (!mounted) return;
      final userType = UserSession.userType;

      // Sadece personel için çalıştır
      if (userType == 'staff' || userType == 'kitchen_staff') {
        debugPrint("[BusinessOwnerHome] Personel kullanıcısı, aktif vardiya bilgisi çekiliyor...");
        try {
          final shiftData = await ApiService.fetchCurrentShift(widget.token);
          if (mounted) {
            setState(() {
              _activeShift = ScheduledShift.fromJson(shiftData);
            });
            _startShiftEndTimer(); // Zamanlayıcıyı başlat
          }
        } catch (e) {
          debugPrint("[BusinessOwnerHome] Aktif vardiya bilgisi alınamadı veya şu an aktif vardiya yok: $e");
          if (mounted) {
            setState(() {
              _activeShift = null;
              _shiftCountdownText = null;
            });
          }
        }
      }
    }

    /// Vardiya bitiş zamanına göre geri sayım sayacını kurar.
    void _startShiftEndTimer() {
      _shiftEndTimer?.cancel(); // Önceki timer'ı iptal et
      if (_activeShift == null) return;

      // DÜZELTME: Artık `_activeShift` (ScheduledShift) üzerinden direkt erişiyoruz.
      final String? endTimeUtcString = _activeShift!.endDateTimeUtc;
      if (endTimeUtcString == null) return;

      final shiftEndTime = DateTime.parse(endTimeUtcString);

      // Her saniye kontrol edecek bir zamanlayıcı başlat
      _shiftEndTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final now = DateTime.now().toUtc();
        final durationUntilEnd = shiftEndTime.difference(now);

        // Vardiya bittiyse
        if (durationUntilEnd.isNegative) {
          if (mounted) {
            setState(() {
              _shiftCountdownText = AppLocalizations.of(context)!.shiftEndedLabel;
            });
          }
          timer.cancel();
          _onShiftEnd(); 
          return;
        }

        // 5 dakikadan az kaldıysa
        if (durationUntilEnd.inMinutes < 5) {
          final minutes = durationUntilEnd.inMinutes;
          final seconds = durationUntilEnd.inSeconds % 60;
          if (mounted) {
            setState(() {
              _shiftCountdownText = AppLocalizations.of(context)!.shiftCountdownLabel(minutes.toString(), seconds.toString().padLeft(2, '0'));
            });
          }
        } else {
          // 5 dakikadan fazla varsa, geri sayımı gösterme
          if (_shiftCountdownText != null) {
             if (mounted) setState(() => _shiftCountdownText = null);
          }
        }
      });
    }
    
    void _onShiftEnd() {
      if (!mounted) return;
      debugPrint("[BusinessOwnerHome] Vardiya sona erdi! Kullanıcıya uyarı gösteriliyor ve çıkış yapması isteniyor.");

      final l10n = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.shiftEndedDialogTitle),
          content: Text(l10n.shiftEndedDialogContent),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); 
                _logout();
              },
              child: Text(l10n.logoutButtonText),
            ),
          ],
        ),
      );
    }
    
    Widget _buildShiftTimerWidget() {
      final l10n = AppLocalizations.of(context)!;
      // Eğer kullanıcı personel değilse veya aktif vardiyası yoksa hiçbir şey gösterme
      if (_activeShift == null || (UserSession.userType != 'staff' && UserSession.userType != 'kitchen_staff')) {
        return const SizedBox.shrink();
      }

      // Geri sayım başlamışsa, onu göster
      if (_shiftCountdownText != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                _shiftCountdownText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }

      // Normal durumda vardiya saatlerini göster
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              '${l10n.shiftLabel}: ${_activeShift!.shift.startTime.format(context)} - ${_activeShift!.shift.endTime.format(context)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    // +++++++++++++++++++++ YENİ EKLENEN METOTLAR SONU (Vardiya Sayacı) +++++++++++++++++++++

    void _setupNotificationCenterListeners() {
        _refreshAllScreensCallback = (data) {
            if (!mounted || !_shouldProcessUpdate()) return;
            final eventType = data['eventType'] as String?;
            final eventData = data['data'] as Map<String, dynamic>?;
            if (data['batchRefresh'] == true) {
                final eventTypes = data['eventTypes'] as List<String>? ?? [];
                debugPrint("[BusinessOwnerHome] 📡 Batch refresh received: ${eventTypes.join(', ')}");
                
                bool shouldRefresh = eventTypes.any((type) => _shouldRefreshForEvent(type));
                if (shouldRefresh) {
                    _throttledEventProcessor('batch_refresh', () async {
                        await _fetchActiveOrderCounts();
                        await _checkStockAlerts();
                    });
                }
                return;
            }
            
            debugPrint("[BusinessOwnerHome] 📡 Global refresh received: $eventType");
            if (_shouldRefreshForEvent(eventType)) {
                _throttledEventProcessor('global_refresh_$eventType', () async {
                    await _fetchActiveOrderCounts();
                    await _checkStockAlerts();
                });
            }
        };

        _screenBecameActiveCallback = (data) {
            if (!mounted || !_shouldProcessUpdate()) return;
            debugPrint("[BusinessOwnerHome] 📱 Screen became active notification received");
            _throttledEventProcessor('screen_active', () async {
                await _fetchActiveOrderCounts();
                await _checkStockAlerts();
            });
        };

        _kdsUpdateCallback = (data) {
            if (!mounted || !_shouldProcessUpdate()) return;
            final eventType = data['event_type'] as String?;
            debugPrint("[BusinessOwnerHome] 🔥 KDS update detected: $eventType");
            if (_isKdsEvent(eventType)) {
                _immediateEventProcessor('kds_update_$eventType', () async {
                    await _fetchActiveOrderCounts();
                    await _checkStockAlerts();
                });
            }
        };

        NotificationCenter.instance.addObserver('refresh_all_screens', _refreshAllScreensCallback);
        NotificationCenter.instance.addObserver('screen_became_active', _screenBecameActiveCallback);
        NotificationCenter.instance.addObserver('order_status_update', _kdsUpdateCallback);
    }

    void _throttledEventProcessor(String eventKey, Future<void> Function() processor) {
        if (_processingEvents.contains(eventKey)) {
            debugPrint("[BusinessOwnerHome] 🚫 Event $eventKey already processing, skipping...");
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
            debugPrint("[BusinessOwnerHome] 🔥 Critical event detected, using immediate processing: $eventKey");
            _immediateEventProcessor(eventKey, processor);
            return;
        }
        
        _eventThrottlers[eventKey] = Timer(const Duration(milliseconds: 300), () async {
            if (!mounted || !_shouldProcessUpdate()) return;
            
            _processingEvents.add(eventKey);
            debugPrint("[BusinessOwnerHome] 🟡 Processing throttled event: $eventKey");
            
            try {
                await processor();
                debugPrint("[BusinessOwnerHome] ✅ Completed throttled event: $eventKey");
            } catch (e) {
                debugPrint("[BusinessOwnerHome] ❌ Error in throttled event $eventKey: $e");
            } finally {
                _processingEvents.remove(eventKey);
                _eventThrottlers.remove(eventKey);
            }
        });
        debugPrint("[BusinessOwnerHome] ⏱️ Throttled event scheduled: $eventKey (300ms delay)");
    }

    void _immediateEventProcessor(String eventKey, Future<void> Function() processor) {
        if (_processingEvents.contains(eventKey)) {
            debugPrint("[BusinessOwnerHome] 🚫 Critical event $eventKey already processing, skipping...");
            return;
        }

        _processingEvents.add(eventKey);
        debugPrint("[BusinessOwnerHome] 🔥 Processing immediate event: $eventKey");
        processor().then((_) {
            debugPrint("[BusinessOwnerHome] ✅ Completed immediate event: $eventKey");
        }).catchError((e) {
            debugPrint("[BusinessOwnerHome] ❌ Error in immediate event $eventKey: $e");
        }).whenComplete(() {
            _processingEvents.remove(eventKey);
        });
    }

    void _cleanupNotificationCenterListeners() {
        NotificationCenter.instance.removeObserver('refresh_all_screens', _refreshAllScreensCallback);
        NotificationCenter.instance.removeObserver('screen_became_active', _screenBecameActiveCallback);
        NotificationCenter.instance.removeObserver('order_status_update', _kdsUpdateCallback);
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

    @override
    void didChangeDependencies() {
        super.didChangeDependencies();
        final route = ModalRoute.of(context);
        if (route is PageRoute) {
            routeObserver.subscribe(this, route);
        }
        
        if (ModalRoute.of(context)?.isCurrent == true && !_isInitialLoadComplete) {
            _safeRefreshDataAsync().then((_) {
                if (mounted) {
                    setState(() { _isInitialLoadComplete = true; });
                }
            });
        }
    }

    @override
    void didPush() {
        _isCurrent = true;
        debugPrint('BusinessOwnerHome: didPush - Ana ekran aktif oldu.');
    }

    @override
    void didPopNext() {
        _isCurrent = true;
        debugPrint("BusinessOwnerHome: didPopNext - Ana ekrana dönüldü, background events işleniyor.");
        
        SocketService.instance.onScreenBecameActive();
        _safeRefreshDataWithThrottling();
        _checkAndReconnectIfNeeded();
    }

    @override
    void didPushNext() {
        _isCurrent = false;
        debugPrint("BusinessOwnerHome: didPushNext - Ana ekran arka plana gitti.");
    }

    @override
    void didPop() {
        _isCurrent = false;
        debugPrint("BusinessOwnerHome: didPop - Ana ekran kapatıldı.");
        routeObserver.unsubscribe(this);
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
        super.didChangeAppLifecycleState(state);
        _isAppInForeground = state == AppLifecycleState.resumed;
        
        if (_isAppInForeground && _isCurrent) {
            debugPrint('BusinessOwnerHome: App foreground\'a geldi, veriler yenileniyor.');
            _safeRefreshDataWithThrottling();
        }
    }

    bool _shouldProcessUpdate() {
        return mounted && _isCurrent && _isAppInForeground;
    }

    void _safeRefreshDataWithThrottling() {
        if (!_shouldProcessUpdate()) return;
        _throttledEventProcessor('business_owner_home_refresh', () async {
            await _fetchActiveOrderCounts();
            await _checkStockAlerts();
        });
    }

    void _safeRefreshData() {
        _safeRefreshDataWithThrottling();
    }

    Future<void> _safeRefreshDataAsync() async {
        if (!_shouldProcessUpdate()) return;
        await _fetchActiveOrderCounts();
        await _checkStockAlerts();
    }

    void _checkAndReconnectIfNeeded() {
        if (!mounted) return;
        try {
            if (!_socketService.isConnected && UserSession.token.isNotEmpty) {
                debugPrint('[BusinessOwnerHome] Socket bağlantısı kopuk, yeniden bağlanılıyor...');
                _socketService.connectAndListen();
                
                if (!ConnectionManager().isMonitoring) {
                    ConnectionManager().startMonitoring();
                } else {
                    ConnectionManager().forceReconnect();
                }
            }
        } catch (e) {
            debugPrint('❌ [BusinessOwnerHome] Connection check hatası: $e');
        }
    }

    void _addSocketServiceAndNotifierListeners() {
        _connectivityService.isOnlineNotifier.addListener(_onConnectivityChanged);
        _socketService.connectionStatusNotifier.addListener(_updateSocketStatusFromService);
        orderStatusUpdateNotifier.addListener(_handleSilentOrderUpdatesThrottled);
        shouldRefreshWaitingCountNotifier.addListener(_handleWaitingCountRefreshThrottled);
        shouldRefreshTablesNotifier.addListener(_handleTablesRefreshThrottled);
        syncStatusMessageNotifier.addListener(_handleSyncStatusMessage);
        stockAlertNotifier.addListener(_onStockAlertUpdate);
        debugPrint("[BusinessOwnerHome] Notifier listener'ları eklendi.");
    }

    void _removeSocketServiceAndNotifierListeners() {
        _connectivityService.isOnlineNotifier.removeListener(_onConnectivityChanged);
        _socketService.connectionStatusNotifier.removeListener(_updateSocketStatusFromService);
        orderStatusUpdateNotifier.removeListener(_handleSilentOrderUpdatesThrottled);
        shouldRefreshWaitingCountNotifier.removeListener(_handleWaitingCountRefreshThrottled);
        shouldRefreshTablesNotifier.removeListener(_handleTablesRefreshThrottled);
        syncStatusMessageNotifier.removeListener(_handleSyncStatusMessage);
        stockAlertNotifier.removeListener(_onStockAlertUpdate);
        debugPrint("[BusinessOwnerHome] Tüm notifier listener'ları kaldırıldı.");
    }

    void _handleTablesRefreshThrottled() {
        if (!_shouldProcessUpdate()) {
            debugPrint('[BusinessOwnerHome] Ekran aktif değil, tables refresh atlandı.');
            return;
        }
        
        _throttledEventProcessor('tables_refresh', () async {
            debugPrint('[BusinessOwnerHome] Enhanced notification tables refresh tetiklendi');
            await _fetchActiveOrderCounts();
            await _checkStockAlerts();
        });
    }

    void _handleWaitingCountRefreshThrottled() {
        if (!_shouldProcessUpdate()) {
            debugPrint('[BusinessOwnerHome] Ekran aktif değil, waiting count refresh atlandı.');
            return;
        }
        
        _throttledEventProcessor('waiting_count_refresh', () async {
            debugPrint('[BusinessOwnerHome] Waiting count refresh tetiklendi');
            await _fetchActiveOrderCounts();
        });
    }

    void _handleSilentOrderUpdatesThrottled() {
        final notificationData = orderStatusUpdateNotifier.value;
        if (notificationData == null || !_shouldProcessUpdate()) {
            if (notificationData != null) {
                debugPrint("[BusinessOwnerHome] Ekran aktif değil, bildirim atlandı: ${notificationData['event_type']}");
            }
            return;
        }
        
        final eventType = notificationData['event_type'] as String?;
        debugPrint("[BusinessOwnerHome] Anlık güncelleme alındı: $eventType");
        
        if (eventType == 'order_item_picked_up' || 
            eventType == 'order_item_delivered' ||
            eventType == 'order_picked_up_by_waiter' ||
            _isPickupDeliveryEvent(eventType)) {
            debugPrint("[BusinessOwnerHome] 🔥 Item pickup/delivery event detected, using immediate processing: $eventType");
            _immediateEventProcessor('pickup_delivery_$eventType', () async {
                await _fetchActiveOrderCounts();
                await _checkStockAlerts();
            });
            return;
        }
        
        if (eventType == 'order_cancelled_update' || eventType == 'order_completed_update') {
            debugPrint("[BusinessOwnerHome] 🔥 Critical order event detected, using priority refresh: $eventType");
            _immediateEventProcessor('critical_order_$eventType', () async {
                await _fetchActiveOrderCounts();
                await _checkStockAlerts();
            });
            return;
        }
        
        if (_isKdsEvent(eventType)) {
            debugPrint("[BusinessOwnerHome] 🔥 KDS event detected, using priority refresh: $eventType");
            _immediateEventProcessor('kds_direct_$eventType', () async {
                await _fetchActiveOrderCounts();
                await _checkStockAlerts();
            });
            return;
        }
        
        if (_shouldRefreshForEvent(eventType) || notificationData['is_paid_update'] == true) {
            _throttledEventProcessor('order_update_$eventType', () async {
                debugPrint("[BusinessOwnerHome] Sayaçları etkileyen bir olay geldi, sayılar yenileniyor.");
                await _fetchActiveOrderCounts();
                await _checkStockAlerts();
            });
        } else {
            debugPrint("[BusinessOwnerHome] Sayaçları etkilemeyen olay, atlandı: $eventType");
        }
    }

    void _onStockAlertUpdate() {
        if (!_shouldProcessUpdate()) return;
        if (_hasStockAlerts != stockAlertNotifier.value) {
            debugPrint("[BusinessOwnerHome] Stok uyarısı durumu güncellendi: ${stockAlertNotifier.value}");
            setState(() {
                _hasStockAlerts = stockAlertNotifier.value;
            });
        }
    }
    
    void _handleSyncStatusMessage() {
        final message = syncStatusMessageNotifier.value;
        if (message != null && _shouldProcessUpdate()) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.teal.shade700,
                ),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
                syncStatusMessageNotifier.value = null;
            });
        }
    }
    
    void _onConnectivityChanged() {
        if(_shouldProcessUpdate()) {
            setState(() {
                debugPrint("BusinessOwnerHome: Connectivity changed. Rebuilding UI.");
            });
            if (_connectivityService.isOnlineNotifier.value) {
                _socketService.connectAndListen();
            }
        }
    }
    
    Future<void> _logout() async {
        debugPrint('[BusinessOwnerHome] Logout işlemi başlatılıyor...');
        try {
            ConnectionManager().stopMonitoring();
            globalHandler.GlobalNotificationHandler.cleanup();
        } catch (e) {
            debugPrint('❌ [BusinessOwnerHome] Logout cleanup hatası: $e');
        }
        
        SocketService.disposeInstance();
        
        UserSession.clearSession();
        if (mounted) {
            navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
            );
        }
    }
    
    // 🆕 ENHANCED: Multiple retry strategy with network connectivity check
    Future<void> _initializeSocketConnection() async {
      try {
        debugPrint('[BusinessOwnerHome] Socket bağlantısı başlatılıyor...');
        
        // 🆕 CRITICAL FIX: Token kontrolü ekle
        if (UserSession.token.isEmpty) {
          debugPrint('[BusinessOwnerHome] ❌ Token empty, aborting socket connection');
          return;
        }
        
        // 🆕 CRITICAL FIX: Token expiry kontrolü
        bool tokenExpired = false;
        try {
          tokenExpired = JwtDecoder.isExpired(UserSession.token);
        } catch (e) {
          debugPrint('[BusinessOwnerHome] Token parse error: $e');
          tokenExpired = true;
        }
        
        if (tokenExpired) {
          debugPrint('[BusinessOwnerHome] ❌ Token expired, aborting socket connection');
          return;
        }
        
        debugPrint('[BusinessOwnerHome] 🔑 Token durumu: ${UserSession.token.isNotEmpty ? "Mevcut ve Geçerli" : "Yok"}');
        debugPrint('[BusinessOwnerHome] 🌐 Base URL: ${ApiService.baseUrl}');
        
        // Kısa bir delay ekle
        await Future.delayed(const Duration(milliseconds: 500)); // 200ms -> 500ms artırıldı
        
        final socketService = SocketService.instance;
        
        // 🆕 ENHANCED: Network connectivity check
        final connectivity = ConnectivityService.instance;
        if (!connectivity.isOnlineNotifier.value) {
          debugPrint('[BusinessOwnerHome] ❌ Network offline, skipping socket connection');
          return;
        }
        
        debugPrint('[BusinessOwnerHome] 🌐 Network online, attempting socket connection...');
        
        // 🆕 ENHANCED: Multiple retry strategy
        int maxAttempts = 3;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          debugPrint('[BusinessOwnerHome] 🔄 Socket connection attempt $attempt/$maxAttempts');
          
          // 🆕 CRITICAL FIX: Her denemede token kontrolü yap
          if (UserSession.token.isEmpty) {
            debugPrint('[BusinessOwnerHome] ❌ Token lost during attempt $attempt');
            return;
          }
          
          final connectFuture = socketService.connectAndListen();
          final timeoutFuture = Future.delayed(const Duration(seconds: 20));
          
          await Future.any([connectFuture, timeoutFuture]);
          
          // Bağlantı kontrolü
          await Future.delayed(const Duration(seconds: 2)); // Socket'in settle olması için bekle
          
          if (socketService.isConnected) {
            debugPrint('[BusinessOwnerHome] ✅ Socket connection successful on attempt $attempt');
            return;
          }
          
          debugPrint('[BusinessOwnerHome] ❌ Socket connection failed on attempt $attempt');
          
          if (attempt < maxAttempts) {
            // Bir sonraki deneme öncesi reset
            debugPrint('[BusinessOwnerHome] 🔄 Preparing for next attempt...');
            await Future.delayed(Duration(seconds: attempt * 2)); // Progressive delay
          }
        }
        
        debugPrint('[BusinessOwnerHome] ❌ All socket connection attempts failed');
        
      } catch (e) {
        debugPrint('[BusinessOwnerHome] Socket başlatma hatası: $e');
      }
    }
    
    Future<void> _initializeAsyncDependencies() async {
        await _loadUserSessionIfNeeded();
        
        // 🔧 FIX 4: Socket bağlantısını optimize edilmiş metod ile başlat
        await _initializeSocketConnection();
        
        await _fetchUserAccessibleKdsScreens();
        
        // +++++++++++++++++++++ YENİ EKLENEN ÇAĞRI (Vardiya Sayacı) +++++++++++++++++++++
        await _fetchAndMonitorShift();
        // +++++++++++++++++++++ YENİ EKLENEN ÇAĞRI SONU +++++++++++++++++++++

        _buildAndSetActiveTabs();
        await _fetchActiveOrderCounts();
        _startOrderCountRefreshTimer();
        await _checkStockAlerts();
        if (!ConnectionManager().isMonitoring) {
            ConnectionManager().startMonitoring();
            debugPrint('[BusinessOwnerHome] Connection manager başlatıldı');
        }
    }
    
    Future<void> _loadUserSessionIfNeeded() async {
        if (UserSession.token.isEmpty && widget.token.isNotEmpty) {
            debugPrint("BusinessOwnerHome: UserSession boş, widget.token ile dolduruluyor.");
            try {
                Map<String, dynamic> decodedToken = JwtDecoder.decode(widget.token);
                UserSession.storeLoginData({'access': widget.token, ...decodedToken});
            } catch (e) {
                debugPrint("BusinessOwnerHome: Token decode error: $e");
                UserSession.clearSession();
                if (mounted) _logout();
            }
        }
    }
    
    Future<void> _checkStockAlerts() async {
        if (!mounted || !UserSession.hasPagePermission(PermissionKeys.manageStock)) {
            if (mounted && _hasStockAlerts) setState(() => _hasStockAlerts = false);
            return;
        }
        
        try {
            final stocks = await StockService.fetchBusinessStock(widget.token);
            bool alertFound = false;
            for (final stock in stocks) {
                if (stock.trackStock && stock.alertThreshold != null && stock.quantity <= stock.alertThreshold!) {
                    alertFound = true;
                    break;
                }
            }
            if (mounted && _hasStockAlerts != alertFound) {
                setState(() => _hasStockAlerts = alertFound);
            }
        } catch (e) {
            debugPrint("Stok uyarıları kontrol edilirken hata: $e");
            if (mounted && _hasStockAlerts) {
                setState(() => _hasStockAlerts = false);
            }
        }
    }
    
    Future<void> _fetchUserAccessibleKdsScreens() async {
        if (!mounted || UserSession.businessId == null) {
            if (mounted) setState(() => _isLoadingKdsScreens = false);
            return;
        }
        if (UserSession.userType == 'customer' || UserSession.userType == 'admin') {
            _availableKdsScreensForUser = [];
            if (mounted) setState(() => _isLoadingKdsScreens = false);
            return;
        }
        if (mounted) setState(() => _isLoadingKdsScreens = true);
        List<KdsScreenModel> kdsToDisplay = [];
        try {
            if (UserSession.userType == 'business_owner') {
                final allKdsScreensForBusiness = await KdsManagementService.fetchKdsScreens(UserSession.token, UserSession.businessId!);
                kdsToDisplay = allKdsScreensForBusiness.where((kds) => kds.isActive).toList();
            } else if (UserSession.userType == 'staff' || UserSession.userType == 'kitchen_staff') {
                kdsToDisplay = UserSession.userAccessibleKdsScreens.where((kds) => kds.isActive).toList();
            }
            
            if (mounted) {
                setState(() => _availableKdsScreensForUser = kdsToDisplay);
                debugPrint("BusinessOwnerHome: Kullanıcı için gösterilecek KDS ekranları (${_availableKdsScreensForUser.length} adet) belirlendi.");
            }
        } catch (e) {
            if (mounted) {
                debugPrint("BusinessOwnerHome: Kullanıcının erişebileceği KDS ekranları işlenirken hata: $e");
                _availableKdsScreensForUser = [];
            }
        } finally {
            if (mounted) setState(() => _isLoadingKdsScreens = false);
        }
    }
    
    void _startOrderCountRefreshTimer() {
        _orderCountRefreshTimer?.cancel();
        _orderCountRefreshTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
            if (_shouldProcessUpdate()) {
                _safeRefreshDataWithThrottling();
                _checkAndReconnectIfNeeded();
            }
        });
    }
    
    Future<void> _fetchActiveOrderCounts() async {
        if (!mounted) return;
        try {
            int kdsCount = 0;
            if (!_isLoadingKdsScreens && _availableKdsScreensForUser.isNotEmpty) {
                kdsCount = await KdsService.fetchActiveKdsOrderCount(widget.token, _availableKdsScreensForUser.first.slug);
            } else {
                kdsCount = 0;
            }

            final results = await Future.wait([
                OrderService.fetchActiveTableOrderCount(widget.token, widget.businessId),
                OrderService.fetchActiveTakeawayOrderCount(widget.token, widget.businessId),
                Future.value(kdsCount)
            ]);
            if (mounted) {
                _activeTableOrderCountNotifier.value = results[0] as int;
                _activeTakeawayOrderCountNotifier.value = results[1] as int;
                _activeKdsOrderCountNotifier.value = results[2] as int;
                debugPrint("[BusinessOwnerHome] Order counts updated - Table: ${results[0]}, Takeaway: ${results[1]}, KDS: ${results[2]}");
            }
        } catch (e) {
            debugPrint("❌ [BusinessOwnerHome] Aktif sipariş sayıları çekilirken hata: $e");
        }
    }
    
    void _updateSocketStatusFromService() {
        if (_shouldProcessUpdate()) {
            final connectionStatus = _socketService.connectionStatusNotifier.value;
            debugPrint("[BusinessOwnerHome] SocketService bağlantı durumu: $connectionStatus");
            
            if (connectionStatus == 'Bağlandı' && 
                _currentKdsRoomSlugForSocketService != null && 
                UserSession.token.isNotEmpty) {
                _socketService.joinKdsRoom(_currentKdsRoomSlugForSocketService!);
            }
            
            if (connectionStatus == 'Bağlandı') {
                Future.delayed(const Duration(seconds: 1), () {
                    if (_shouldProcessUpdate()) {
                        _safeRefreshDataWithThrottling();
                    }
                });
            }
        }
    }

    bool _canAccessTab(String permissionKey) {
        if (UserSession.userType == 'business_owner') return true;
        if (permissionKey == PermissionKeys.manageKds ||
            permissionKey == PermissionKeys.managePagers ||
            permissionKey == PermissionKeys.manageCampaigns ||
            permissionKey == PermissionKeys.manageKdsScreens) {
            return UserSession.userType == 'business_owner' ||
                UserSession.hasPagePermission(permissionKey);
        }
        return UserSession.hasPagePermission(permissionKey);
    }
    
    Widget _buildIconWithBadge(IconData defaultIcon, IconData activeIcon, ValueNotifier<int> countNotifier) {
        return ValueListenableBuilder<int>(
            valueListenable: countNotifier,
            builder: (context, count, child) {
                bool isSelected = (_currentIndex == 1 && defaultIcon == Icons.table_chart_outlined) ||
                                  (_currentIndex == 2 && defaultIcon == Icons.delivery_dining_outlined) ||
                                  (_activeNavBarItems.length > 3 && _currentIndex == 3 && _activeNavBarItems[3].label == AppLocalizations.of(context)!.kitchenTabLabel && defaultIcon == Icons.kitchen_outlined);

                return Badge(
                    label: Text(count > 99 ? '99+' : count.toString()),
                    isLabelVisible: count > 0,
                    backgroundColor: Colors.redAccent,
                    child: Icon(isSelected ? activeIcon : defaultIcon),
                );
            },
        );
    }
    
    void _navigateToKdsScreen(BuildContext context) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;

        if (_isLoadingKdsScreens) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.infoKdsScreensLoading), duration: const Duration(seconds: 1)),
            );
            return;
        }

        if (_availableKdsScreensForUser.isEmpty) {
            if (UserSession.userType == 'business_owner') {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.infoCreateKdsScreenFirst)),
                );
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ManageKdsScreensScreen(token: widget.token, businessId: widget.businessId),
                    ),
                ).then((_) => _fetchUserAccessibleKdsScreens().then((__) {
                    if (mounted) _buildAndSetActiveTabs();
                }));
            } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.infoNoActiveKdsAvailable)),
                );
            }
            return;
        }

        if (_availableKdsScreensForUser.length == 1) {
            final kds = _availableKdsScreensForUser.first;
            _currentKdsRoomSlugForSocketService = kds.slug;
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => KdsScreen(
                        token: widget.token,
                        businessId: widget.businessId,
                        kdsScreenSlug: kds.slug,
                        kdsScreenName: kds.name,
                        onGoHome: () => _onNavBarTapped(0),
                        socketService: _socketService,
                    ),
                ),
            );
        } else {
            showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                    return AlertDialog(
                        backgroundColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        content: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                colors: [
                                    Colors.blue.shade900.withOpacity(0.95),
                                    Colors.blue.shade500.withOpacity(0.9),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                                ]
                            ),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Text(
                                        l10n.dialogSelectKdsScreenTitle,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                        ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(color: Colors.white30),
                                    SizedBox(
                                        width: double.maxFinite,
                                        height: MediaQuery.of(context).size.height * 0.3,
                                        child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _availableKdsScreensForUser.length,
                                            itemBuilder: (BuildContext ctx, int index) {
                                                final kds = _availableKdsScreensForUser[index];
                                                return ListTile(
                                                    leading: const Icon(Icons.desktop_windows_rounded, color: Colors.white70),
                                                    title: Text(kds.name, style: const TextStyle(color: Colors.white)),
                                                    onTap: () {
                                                        Navigator.of(dialogContext).pop();
                                                        _currentKdsRoomSlugForSocketService = kds.slug;
                                                        Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                                builder: (_) => KdsScreen(
                                                                    token: widget.token,
                                                                    businessId: widget.businessId,
                                                                    kdsScreenSlug: kds.slug,
                                                                    kdsScreenName: kds.name,
                                                                    onGoHome: () => _onNavBarTapped(0),
                                                                    socketService: _socketService,
                                                                ),
                                                            ),
                                                        );
                                                    },
                                                );
                                            },
                                        ),
                                    ),
                                    Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                            child: Text(l10n.dialogButtonCancel, style: const TextStyle(color: Colors.white70)),
                                            onPressed: () {
                                                Navigator.of(dialogContext).pop();
                                            },
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    );
                },
            );
        }
    }
    
    void _buildAndSetActiveTabs() {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;

        final List<Widget> pages = [];
        final List<BottomNavigationBarItem> navBarItems = [];
        pages.add(BusinessOwnerHomeContent(
            token: widget.token,
            businessId: widget.businessId,
            onTabChange: _onNavBarTapped,
            onNavigateToKds: () => _navigateToKdsScreen(context),
            hasStockAlerts: _hasStockAlerts,
        ));
        navBarItems.add(BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l10n.homeTabLabel));
        if (_canAccessTab(PermissionKeys.takeOrders)) {
            pages.add(CreateOrderScreen(
                token: widget.token,
                businessId: widget.businessId,
                onGoHome: () => _onNavBarTapped(0),
            ));
            navBarItems.add(BottomNavigationBarItem(
                icon: _buildIconWithBadge(Icons.table_chart_outlined, Icons.table_chart, _activeTableOrderCountNotifier),
                label: l10n.tableTabLabel));
            pages.add(TakeawayOrderScreen(
                token: widget.token,
                businessId: widget.businessId,
                onGoHome: () => _onNavBarTapped(0),
            ));
            navBarItems.add(BottomNavigationBarItem(
                icon: _buildIconWithBadge(Icons.delivery_dining_outlined, Icons.delivery_dining, _activeTakeawayOrderCountNotifier),
                label: l10n.takeawayTabLabel));
        }

        bool showKdsTab = false;
        bool showKdsSetupTab = false;
        if (!_isLoadingKdsScreens) {
            bool hasGeneralKdsPermission = UserSession.userType == 'business_owner' ||
                UserSession.hasPagePermission(PermissionKeys.manageKds);

            if (hasGeneralKdsPermission) {
                if (_availableKdsScreensForUser.isNotEmpty) {
                    showKdsTab = true;
                } else if (UserSession.userType == 'business_owner') {
                    showKdsSetupTab = true;
                }
            }
        }
        
        if (showKdsTab) {
            pages.add(Container(alignment: Alignment.center, child: Text(l10n.infoKdsSelectionPending, style: const TextStyle(color: Colors.white70))));
            navBarItems.add(BottomNavigationBarItem(
                icon: _buildIconWithBadge(Icons.kitchen_outlined, Icons.kitchen, _activeKdsOrderCountNotifier),
                label: l10n.kitchenTabLabel));
        } else if (showKdsSetupTab) {
            pages.add(Center(child: ElevatedButton(onPressed: (){
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ManageKdsScreensScreen(token: widget.token, businessId: widget.businessId),
                    ),
                ).then((_) => _fetchUserAccessibleKdsScreens().then((__) {
                    if(mounted) _buildAndSetActiveTabs();
                }));
            }, child: Text(l10n.buttonCreateKdsScreen))));
            navBarItems.add(BottomNavigationBarItem(
                icon: const Icon(Icons.add_to_queue_outlined),
                activeIcon: const Icon(Icons.add_to_queue),
                label: l10n.kdsSetupTabLabel));
        }

        pages.add(NotificationScreen(
            token: widget.token,
            businessId: widget.businessId,
            onGoHome: () => _onNavBarTapped(0),
        ));
        navBarItems.add(BottomNavigationBarItem(
            icon: const Icon(Icons.notifications_outlined),
            activeIcon: const Icon(Icons.notifications),
            label: l10n.notificationsTabLabel));
        if (!listEquals(_activeTabPages, pages) || !listEquals(_activeNavBarItems, navBarItems)) {
            setState(() {
                _activeTabPages = pages;
                _activeNavBarItems = navBarItems;
            });
        }
        
        int newCurrentIndex = _currentIndex;
        if (newCurrentIndex >= pages.length && pages.isNotEmpty) {
            newCurrentIndex = 0;
        }
        if (_currentIndex != newCurrentIndex){
            setState(() {
                _currentIndex = newCurrentIndex;
            });
        }
    }

    void _onNavBarTapped(int index) {
        if (!mounted) return;
        String? tappedLabel;
        if (index >= 0 && index < _activeNavBarItems.length) {
            tappedLabel = _activeNavBarItems[index].label;
        }
        
        final l10n = AppLocalizations.of(context)!;
        if (tappedLabel == l10n.kitchenTabLabel) {
            _navigateToKdsScreen(context);
            return;
        } else if (tappedLabel == l10n.kdsSetupTabLabel) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ManageKdsScreensScreen(token: widget.token, businessId: widget.businessId),
                ),
            ).then((_) => _fetchUserAccessibleKdsScreens().then((__) {
                if(mounted) _buildAndSetActiveTabs();
            }));
            return;
        }

        if (index >= 0 && index < _activeTabPages.length) {
            if (_currentIndex == index && index != 0) return;
            setState(() {
                _currentIndex = index;
            });
        } else if (_currentIndex != 0) {  
            setState(() {
                _currentIndex = 0;
            });
        }
    }
    
    String _getAppBarTitle(AppLocalizations l10n) {
        switch (UserSession.userType) {
            case 'kitchen_staff':
                return l10n.homePageTitleKitchenStaff;
            case 'staff':
                return l10n.homePageTitleStaff;
            case 'business_owner':
            default:
                return l10n.homePageTitleBusinessOwner;
        }
    }

    Widget _buildConnectionStatusIndicator() {
        return ValueListenableBuilder<String>(
            valueListenable: _socketService.connectionStatusNotifier,
            builder: (context, status, child) {
                Color indicatorColor;
                IconData indicatorIcon;
                
                if (status == 'Bağlandı') {
                    indicatorColor = Colors.green;
                    indicatorIcon = Icons.wifi;
                } else if (status.contains('bekleniyor') || status.contains('deneniyor')) {
                    indicatorColor = Colors.orange;
                    indicatorIcon = Icons.wifi_tethering;
                } else {
                    indicatorColor = Colors.red;
                    indicatorIcon = Icons.wifi_off;
                }
                
                return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                        onTap: _checkAndReconnectIfNeeded,
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: indicatorColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                                indicatorIcon,
                                color: indicatorColor,
                                size: 16,
                            ),
                        ),
                    ),
                );
            },
        );
    }

    @override
    Widget build(BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        if (_activeTabPages.isEmpty &&
                !(UserSession.userType == 'customer' ||
                    UserSession.userType == 'admin')) {
            return Scaffold(
                appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: true,
                    title: Text(
                        _getAppBarTitle(l10n),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    flexibleSpace: Container(
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [Color(0xFF283593), Color(0xFF455A64)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight))),
                    actions: [
                        _buildConnectionStatusIndicator(),
                        UserProfileAvatar(onLogout: _logout),
                    ],
                ),
                body: Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                                Colors.blue.shade900.withOpacity(0.9),
                                Colors.blue.shade400.withOpacity(0.8)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white))),
            );
        }

        int safeCurrentIndex = _currentIndex;
        if (_currentIndex >= _activeTabPages.length && _activeTabPages.isNotEmpty) {
            safeCurrentIndex = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _currentIndex != safeCurrentIndex) {
                    setState(() => _currentIndex = safeCurrentIndex);
                }
            });
        } else if (_activeTabPages.isEmpty &&
            _currentIndex != 0 &&
            (UserSession.userType != 'customer' &&
                UserSession.userType != 'admin')) {
            safeCurrentIndex = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _currentIndex != safeCurrentIndex) {
                    setState(() => _currentIndex = safeCurrentIndex);
                }
            });
        }

        return Scaffold(
            appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: Text(
                    _getAppBarTitle(l10n),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                ),
                // +++++++++++++++++++++ YENİ: AppBar'ın 'bottom' özelliği eklendi +++++++++++++++++++++
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(40.0),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildShiftTimerWidget(), // Oluşturduğumuz widget'ı buraya yerleştiriyoruz
                  ),
                ),
                // +++++++++++++++++++++ YENİ BÖLÜM SONU +++++++++++++++++++++
                flexibleSpace: Container(
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFF283593), Color(0xFF455A64)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                    ),
                ),
                leading: (_activeTabPages.isNotEmpty && safeCurrentIndex < _activeTabPages.length && _activeTabPages[safeCurrentIndex] is! BusinessOwnerHomeContent) && 
                    (_activeNavBarItems.isNotEmpty && safeCurrentIndex < _activeNavBarItems.length && _activeNavBarItems[safeCurrentIndex].label != l10n.kitchenTabLabel && _activeNavBarItems[safeCurrentIndex].label != l10n.kdsSetupTabLabel)
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: l10n.tooltipGoToHome,
                        onPressed: () => _onNavBarTapped(0),
                    )
                    : null,
                actions: [
                    _buildConnectionStatusIndicator(),
                    UserProfileAvatar(onLogout: _logout),
                ],
            ),
            body: Column(
                children: [
                    const OfflineBanner(),
                    const SyncStatusIndicator(),
                    Expanded(
                        child: Container(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                        Colors.blue.shade900.withOpacity(0.9),
                                        Colors.blue.shade400.withOpacity(0.8)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight)),
                            child: SafeArea(
                                top: false,
                                child: _activeTabPages.isEmpty
                                    ? Center(child: Text(l10n.infoContentLoading, style: const TextStyle(color: Colors.white)))
                                    : IndexedStack(
                                        index: safeCurrentIndex,
                                        children: _activeTabPages,
                                    ),
                            ),
                        ),
                    ),
                ],
            ),
            bottomNavigationBar: _activeNavBarItems.length > 1
                ? Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                                Colors.deepPurple.shade700,
                                Colors.blue.shade800,
                                Colors.teal.shade700
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, -1))
                        ],
                    ),
                    child: BottomNavigationBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        currentIndex: safeCurrentIndex,
                        onTap: _onNavBarTapped,
                        type: BottomNavigationBarType.fixed,
                        selectedItemColor: Colors.white,
                        unselectedItemColor: Colors.white.withOpacity(0.65),
                        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                        unselectedLabelStyle: const TextStyle(fontSize: 10),
                        items: _activeNavBarItems,
                    ),
                )
                : null,
        );
    }
}
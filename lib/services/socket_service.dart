// lib/services/socket_service.dart

import 'notification_center.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/widgets.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'api_service.dart';
import 'user_session.dart';
import 'global_notification_handler.dart';
import '../utils/notifiers.dart';
import '../models/notification_event_types.dart';
import 'connection_manager.dart';
import 'connectivity_service.dart';

class SocketService extends ChangeNotifier {
  // === STATIC INITIALIZATION GUARD ===
  static bool _initializationAllowed = true;

  /// Engeller: logout sırasında çağrılacak
  static void blockInitialization() {
    debugPrint('[SocketService] initialize blocked by blockInitialization()');
    _initializationAllowed = false;
  }

  /// İzin ver: login sırasında çağrılacak
  static void allowInitialization() {
    debugPrint('[SocketService] initialize allowed by allowInitialization()');
    _initializationAllowed = true;
    
    if (_instance != null && _instance!._isDisposed) {
      debugPrint('[SocketService] Disposed instance detected, clearing...');
      _instance = null;
    }
  }

  /// Public getter so other modules can check whether initialization is allowed.
  static bool get initializationAllowed => _initializationAllowed;

  /// Track last dispose time so we can avoid rapid re-init races with native socket layer.
  static DateTime? _lastDisposedAt;

  /// initialize now respects initializationAllowed and token presence.
  /// Use force: true to bypass guards (use cautiously in tests).
  static void initialize({bool force = false}) {
    debugPrint("[SocketService] initialize() çağrıldı. force: $force");
    if (!force && !_initializationAllowed) {
      debugPrint('[SocketService] initialize() atlandı - initializationBlocked.');
      return;
    }
    if (!force && UserSession.token.isEmpty) {
      debugPrint('[SocketService] initialize() atlandı - UserSession.token boş.');
      return;
    }
    if (_instance != null) {
      disposeInstance();
    }
    final _ = instance; // will create instance if not exists
  }
  // === /STATIC INITIALIZATION GUARD ===

  static SocketService? _instance;
  static SocketService get instance {
    _instance ??= SocketService._internal();
    return _instance!;
  }

  static void disposeInstance() {
    if (_instance != null) {
      debugPrint('[SocketService] disposeInstance() çağrıldı. Instance null yapıldı.');
      try {
        _instance?.dispose();
      } catch (e) {
        debugPrint('[SocketService] disposeInstance dispose error: $e');
      } finally {
        _instance = null;
        _lastDisposedAt = DateTime.now();
        _initializationAllowed = false;
      }
    }
  }

  SocketService._internal();

  IO.Socket? _socket;
  final ValueNotifier<String> connectionStatusNotifier = ValueNotifier('Bağlantı bekleniyor...');
  final ValueNotifier<List<Map<String, String>>> notificationHistoryNotifier = ValueNotifier([]);

  String? _currentKdsRoomSlug;
  bool _isDisposed = false;

  // guards and watchdog
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isRefreshingToken = false;
  Timer? _connectWatchdog;
  Timer? _reconnectTimer;
  Timer? _periodicPingTimer;
  int _connectionAttempts = 0;

  // Connect start time tracking
  DateTime? _connectStartTime;
  Timer? _connectTimeout;

  // === YENİ EKLENEN: CONNECTION FAILURE TRACKING ===
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;
  static const int _maxConsecutiveFailures = 3;
  static const Duration _failureCooldown = Duration(minutes: 2);

  // permanent failure state - when refresh token is invalid / session expired permanently
  bool _permanentAuthFailure = false;
  int _watchdogRetryCount = 0;
  static const int _maxWatchdogRetries = 3;

  // dedupe & queues
  final Set<String> _processedNotificationIds = <String>{};
  final Map<String, DateTime> _lastEventTimes = <String, DateTime>{};
  final List<Map<String, dynamic>> _backgroundEventQueue = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _priorityKdsEventQueue = <Map<String, dynamic>>[];

  static const Map<String, Duration> _eventCooldowns = {
    NotificationEventTypes.orderApprovedForKitchen: Duration(milliseconds: 50),
    NotificationEventTypes.orderReadyForPickupUpdate: Duration(milliseconds: 50),
    NotificationEventTypes.orderItemAdded: Duration(milliseconds: 200),
    NotificationEventTypes.orderPreparingUpdate: Duration(milliseconds: 500),
    NotificationEventTypes.orderCancelledUpdate: Duration(seconds: 1),
    NotificationEventTypes.guestOrderPendingApproval: Duration(milliseconds: 100),
    NotificationEventTypes.existingOrderNeedsReapproval: Duration(milliseconds: 100),
  };

  static const Map<String, Duration> _kdsEventCooldowns = {
    'order_preparing_update': Duration(milliseconds: 25),
    'order_ready_for_pickup_update': Duration(milliseconds: 25),
    'order_item_picked_up': Duration(milliseconds: 50),
    'order_fully_delivered': Duration(milliseconds: 100),
  };

  static const Duration _defaultCooldown = Duration(seconds: 2);

  IO.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;
  bool get isConnecting => _isConnecting;

  static const Set<String> _loudNotificationEvents = {
    NotificationEventTypes.guestOrderPendingApproval,
    NotificationEventTypes.existingOrderNeedsReapproval,
    NotificationEventTypes.orderApprovedForKitchen,
    NotificationEventTypes.orderReadyForPickupUpdate,
    NotificationEventTypes.orderItemAdded,
    NotificationEventTypes.orderPreparingUpdate,
  };
  static const Set<String> _infoNotificationEvents = {
    NotificationEventTypes.waitingCustomerAdded,
    'secondary_info_update',
  };
  static const Set<String> _kdsHighPriorityEvents = {
    'order_preparing_update',
    'order_ready_for_pickup_update',
    'order_item_picked_up',
    'order_fully_delivered',
  };

  bool checkConnection() => isConnected;

  bool _isKdsEvent(String? eventType) {
    if (eventType == null) return false;
    return _kdsHighPriorityEvents.contains(eventType) ||
        eventType.contains('preparing') ||
        eventType.contains('ready_for_pickup') ||
        eventType.contains('picked_up') ||
        eventType.contains('kds') ||
        eventType.contains('delivered');
  }

  // === YENİ EKLENEN: CONNECTION FAILURE MANAGEMENT ===
  void _recordConnectionFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    debugPrint('[SocketService] Connection failure recorded. Count: $_consecutiveFailures');
    
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      debugPrint('[SocketService] Max consecutive failures reached. Entering cooldown mode.');
      _setConnectionStatus('Çok fazla bağlantı hatası - dinlenme modu');
      
      // Cooldown süresi sonunda otomatik retry
      Timer(_failureCooldown, () {
        if (!_isDisposed && UserSession.token.isNotEmpty && _initializationAllowed) {
          debugPrint('[SocketService] Cooldown ended, resetting failure count and retrying...');
          _consecutiveFailures = 0;
          _lastFailureTime = null;
          connectAndListen();
        }
      });
    }
  }
  
  void _resetConnectionFailures() {
    if (_consecutiveFailures > 0) {
      debugPrint('[SocketService] Connection success - resetting failure count');
      _consecutiveFailures = 0;
      _lastFailureTime = null;
    }
  }
  
  bool _isInFailureCooldown() {
    if (_lastFailureTime == null || _consecutiveFailures < _maxConsecutiveFailures) {
      return false;
    }
    
    final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
    final inCooldown = timeSinceLastFailure < _failureCooldown;
    
    if (inCooldown) {
      final remainingTime = _failureCooldown - timeSinceLastFailure;
      debugPrint('[SocketService] Still in failure cooldown. Remaining: ${remainingTime.inSeconds}s');
    }
    
    return inCooldown;
  }

  void _setConnectionStatus(String status) {
    if (_isDisposed) {
      debugPrint('[SocketService] _setConnectionStatus suppressed (disposed): $status');
      return;
    }
    try {
      connectionStatusNotifier.value = status;
    } catch (e) {
      debugPrint('[SocketService] _setConnectionStatus failed: $e');
    }
  }

  void _startConnectWatchdog() {
    _clearConnectWatchdog();
    _connectWatchdog = Timer(const Duration(seconds: 25), () async { // 20->25 saniye artırıldı
      debugPrint('[SocketService] connect watchdog tetiklendi - starting cleanup & retry');
      
      _recordConnectionFailure(); // Failure kaydet
      
      try {
        await _forceCompleteReset();
      } catch (e) {
        debugPrint('[SocketService] Watchdog dispose error: $e');
      }

      if (_permanentAuthFailure) {
        debugPrint('[SocketService] Watchdog: permanentAuthFailure aktif - retry iptal ediliyor.');
        NotificationCenter.instance.postNotification('auth_refresh_failed', {'reason': 'permanent_auth_failure_on_watchdog'});
        return;
      }

      if (!_initializationAllowed) {
        debugPrint('[SocketService] Watchdog: initialization not allowed - retry iptal ediliyor.');
        NotificationCenter.instance.postNotification('auth_refresh_failed', {'reason': 'initialization_blocked_on_watchdog'});
        return;
      }

      if (UserSession.token.isEmpty || UserSession.refreshToken.isEmpty) {
        debugPrint('[SocketService] Watchdog: token veya refreshToken yok -> retry iptal ediliyor.');
        NotificationCenter.instance.postNotification('auth_refresh_failed', {'reason': 'no_tokens_on_watchdog'});
        return;
      }

      _watchdogRetryCount++;
      if (_watchdogRetryCount > _maxWatchdogRetries) {
        debugPrint('[SocketService] Watchdog: max retry sayısına ulaşıldı ($_watchdogRetryCount).');
        NotificationCenter.instance.postNotification('auth_refresh_failed', {'reason': 'max_watchdog_retries_reached'});
        return;
      }

      // === YENİ: FAILURE COOLDOWN KONTROLÜ ===
      if (_isInFailureCooldown()) {
        debugPrint('[SocketService] Watchdog: failure cooldown aktif - retry atlanıyor.');
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500)); // 250->500ms artırıldı
      if (!_isDisposed) {
        debugPrint('[SocketService] connect watchdog retrying connectAndListen() (attempt #$_watchdogRetryCount)');
        connectAndListen();
      }
    });
  }

  void _clearConnectWatchdog() {
    try {
      _connectWatchdog?.cancel();
    } catch (_) {}
    _connectWatchdog = null;
  }

  Future<void> _forceCompleteReset() async {
    debugPrint("[SocketService] 🔄 FORCE COMPLETE RESET başlatılıyor...");
    
    // Tüm flag'leri kesin olarak temizle
    _isConnecting = false;
    _isConnected = false;
    _isRefreshingToken = false;
    _connectStartTime = null;
    _watchdogRetryCount = 0;
    _permanentAuthFailure = false;
    
    // Tüm timer'ları durdur
    _clearConnectWatchdog();
    _clearConnectTimeout();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _periodicPingTimer?.cancel();
    _periodicPingTimer = null;
    
    // Socket'i tamamen yoket
    if (_socket != null) {
      try {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.dispose();
      } catch (e) {
        debugPrint("[SocketService] Socket destroy error: $e");
      }
      _socket = null;
    }
    
    // Event queue'ları temizle
    _processedNotificationIds.clear();
    _lastEventTimes.clear();
    _backgroundEventQueue.clear();
    _priorityKdsEventQueue.clear();
    
    // Connection status'u güncelle
    if (!_isDisposed) {
      _setConnectionStatus('Bağlantı bekleniyor...');
    }
    
    await Future.delayed(const Duration(milliseconds: 2000)); // 1500->2000ms artırıldı
    
    debugPrint("[SocketService] 🔄 FORCE COMPLETE RESET tamamlandı");
  }

  void _startConnectTimeout() {
    _clearConnectTimeout();
    _connectTimeout = Timer(const Duration(seconds: 20), () async { // 15->20 saniye artırıldı
      if (_socket?.connected != true) {
        debugPrint("[SocketService] ⏰ Connect timeout after 20 seconds");
        
        _recordConnectionFailure(); // Failure kaydet
        
        await _forceCompleteReset();
        
        // === YENİ: FAILURE COOLDOWN KONTROLÜ ===
        if (!_isInFailureCooldown()) {
          Timer(const Duration(seconds: 5), () { // 3->5 saniye artırıldı
            if (!_isDisposed && UserSession.token.isNotEmpty && _initializationAllowed) {
              debugPrint("[SocketService] 🔄 Retrying after timeout...");
              connectAndListen();
            }
          });
        }
      }
      _clearConnectTimeout();
    });
  }

  void _clearConnectTimeout() {
    try {
      _connectTimeout?.cancel();
    } catch (_) {}
    _connectTimeout = null;
  }

  bool _shouldProcessNotification(String? notificationId, String? eventType) {
    final now = DateTime.now();
    final isKdsEvent = _isKdsEvent(eventType);

    if (notificationId != null) {
      final duplicateTimeout = isKdsEvent ? 10 : 30;
      final existingTime = _processedNotificationIds.contains(notificationId) ? _lastEventTimes[notificationId] : null;
      if (existingTime != null && now.difference(existingTime).inSeconds < duplicateTimeout) {
        return false;
      }
      _processedNotificationIds.add(notificationId);
      _lastEventTimes[notificationId] = now;
    }

    if (eventType != null) {
      final cooldownKey = '${eventType}_cooldown';
      final lastTime = _lastEventTimes[cooldownKey];

      Duration cooldownDuration;
      if (isKdsEvent && _kdsEventCooldowns.containsKey(eventType)) {
        cooldownDuration = _kdsEventCooldowns[eventType]!;
      } else {
        cooldownDuration = _eventCooldowns[eventType] ?? _defaultCooldown;
      }

      if (lastTime != null && now.difference(lastTime) < cooldownDuration) {
        return false;
      }
      _lastEventTimes[cooldownKey] = now;
    }

    if (_processedNotificationIds.length > 50) {
      final oldEntries = _processedNotificationIds.take(25).toList();
      _processedNotificationIds.removeAll(oldEntries);
      oldEntries.forEach(_lastEventTimes.remove);
    }

    final cleanupTimeout = isKdsEvent ? Duration(minutes: 3) : Duration(minutes: 5);
    final cooldownKeysToRemove = <String>[];
    for (final entry in _lastEventTimes.entries) {
      if (entry.key.endsWith('_cooldown') && DateTime.now().difference(entry.value) > cleanupTimeout) {
        cooldownKeysToRemove.add(entry.key);
      }
    }
    cooldownKeysToRemove.forEach(_lastEventTimes.remove);

    return true;
  }

  void _processPriorityKdsQueue() {
    if (_priorityKdsEventQueue.isEmpty) return;

    final eventsToProcess = List<Map<String, dynamic>>.from(_priorityKdsEventQueue);
    _priorityKdsEventQueue.clear();
    for (final event in eventsToProcess) {
      _processEventData(event, isBackgroundProcessing: true, isPriorityKds: true);
    }
  }

  void _processBackgroundQueue() {
    _processPriorityKdsQueue();
    if (_backgroundEventQueue.isEmpty) return;

    final eventsToProcess = List<Map<String, dynamic>>.from(_backgroundEventQueue);
    _backgroundEventQueue.clear();
    for (final event in eventsToProcess) {
      _processEventData(event, isBackgroundProcessing: true);
    }
  }

  void _processEventData(Map<String, dynamic> data, {bool isBackgroundProcessing = false, bool isPriorityKds = false}) {
    final String? eventType = data['event_type'] as String?;
    if (eventType == null) return;

    final isKdsEvent = _isKdsEvent(eventType);
    if (isPriorityKds || isKdsEvent) {
      NotificationCenter.instance.postNotification('kds_priority_update', data);
    }

    final String? kdsSlug = data['kds_slug'] as String?;
    if (kdsSlug != null) {
      kdsUpdateNotifier.value = Map<String, dynamic>.from(data);
    } else {
      orderStatusUpdateNotifier.value = Map<String, dynamic>.from(data);
    }

    if (!isBackgroundProcessing) {
      shouldRefreshTablesNotifier.value = true;
      _triggerGlobalRefresh(eventType, data, isKdsEvent: isKdsEvent);
    }

    if (eventType != null && UserSession.hasNotificationPermission(eventType)) {
      _addNotificationToHistory(data['message'] ?? 'Update', eventType);
      if (_loudNotificationEvents.contains(eventType)) {
        GlobalNotificationHandler.instance.addNotification(data);
      } else if (_infoNotificationEvents.contains(eventType)) {
        informationalNotificationNotifier.value = Map<String, dynamic>.from(data);
      }
    }
  }

  void _triggerGlobalRefresh(String eventType, Map<String, dynamic> data, {bool isKdsEvent = false}) {
    if (isKdsEvent) {
      NotificationCenter.instance.postNotification('kds_priority_update', data);
    }
    NotificationCenter.instance.postNotification('refresh_all_screens', {'eventType': eventType, 'data': data});
  }

  // === GÜNCELLENMİŞ: Enhanced Token Refresh with Retry Logic ===
  Future<bool> _attemptRefreshAndReconnect() async {
    if (_isRefreshingToken) {
      debugPrint('[SocketService] Zaten token yenileniyor, bekleniyor.');
      
      // 30 saniye timeout ile bekle
      int waitCount = 0;
      while (_isRefreshingToken && waitCount < 200) { // 30 saniye
        await Future.delayed(const Duration(milliseconds: 150));
        waitCount++;
      }
      
      if (_isRefreshingToken) {
        debugPrint('[SocketService] Token refresh timeout, başarısız sayılıyor.');
        return false;
      }
      
      try {
        final stillExpired = JwtDecoder.isExpired(UserSession.token);
        return !stillExpired;
      } catch (_) {
        return false;
      }
    }

    _isRefreshingToken = true;
    debugPrint('[SocketService] Token yenileme denemesi başlatılıyor...');

    final refreshToken = UserSession.refreshToken;
    if (refreshToken.isEmpty) {
      debugPrint('[SocketService] Refresh token yok, auth_refresh_failed bildirimi atılıyor.');
      NotificationCenter.instance.postNotification('auth_refresh_failed', {'reason': 'no_refresh_token'});
      _isRefreshingToken = false;
      _permanentAuthFailure = true;
      ConnectionManager().stopMonitoring();
      return false;
    }

    // === YENİ: Multiple refresh attempts with exponential backoff ===
    int refreshAttempts = 0;
    const maxRefreshAttempts = 3;
    
    while (refreshAttempts < maxRefreshAttempts) {
      try {
        if (refreshAttempts > 0) {
          final backoffDelay = Duration(seconds: 2 * refreshAttempts);
          debugPrint('[SocketService] Token refresh attempt $refreshAttempts after ${backoffDelay.inSeconds}s delay');
          await Future.delayed(backoffDelay);
        }
        
        final newTokens = await ApiService.refreshToken(refreshToken);
        final newAccess = newTokens['access'];
        final newRefresh = newTokens['refresh'] ?? refreshToken;
        
        if (newAccess != null) {
          debugPrint('[SocketService] Token yenileme başarılı (attempt ${refreshAttempts + 1}).');
          await UserSession.updateTokens(accessToken: newAccess, refreshToken: newRefresh);
          
          _watchdogRetryCount = 0;
          _permanentAuthFailure = false;
          _resetConnectionFailures(); // Success durumunda failure count'u sıfırla
          
          _isRefreshingToken = false;
          return true;
        } else {
          throw Exception('Token refresh response invalid: no access token');
        }
        
      } catch (e) {
        refreshAttempts++;
        debugPrint('[SocketService] Token yenileme başarısız (attempt $refreshAttempts): $e');
        
        final err = e.toString().toLowerCase();
        if (err.contains('token_not_valid') || err.contains('oturum süresi doldu') || err.contains('refresh token')) {
          debugPrint('[SocketService] Token yenileme hatası token_not_valid içeriyor; permanentAuthFailure=true');
          _permanentAuthFailure = true;
          ConnectionManager().stopMonitoring();
          NotificationCenter.instance.postNotification('auth_refresh_failed', {'reason': 'invalid_refresh_token', 'error': e.toString()});
          _isRefreshingToken = false;
          return false;
        }
        
        // Son denemeyse hata fırlat
        if (refreshAttempts >= maxRefreshAttempts) {
          debugPrint('[SocketService] Max token refresh attempts reached, failing.');
          NotificationCenter.instance.postNotification('auth_refresh_failed', {'reason': 'refresh_failed_max_attempts', 'error': e.toString()});
          _isRefreshingToken = false;
          return false;
        }
      }
    }
    
    _isRefreshingToken = false;
    return false;
  }

  Future<void> connectAndListen() async {
    // === YENİ: FAILURE COOLDOWN KONTROLÜ ===
    if (_isInFailureCooldown()) {
      debugPrint("[SocketService] connectAndListen atlandı - failure cooldown aktif.");
      return;
    }

    // Always force reset if connecting
    if (_isConnecting) {
      debugPrint('[SocketService] 🔄 Force reset due to existing connecting state');
      await _forceCompleteReset();
    }

    if (!_initializationAllowed) {
      debugPrint("[SocketService] connectAndListen blocked - initialization not allowed.");
      return;
    }

    // If we recently disposed the service, give native layer a small grace period
    if (_lastDisposedAt != null) {
      final since = DateTime.now().difference(_lastDisposedAt!);
      if (since < const Duration(milliseconds: 2500)) { // 1500->2500ms artırıldı
        final waitMs = 1200; // 800->1200ms artırıldı
        debugPrint('[SocketService] Recent dispose detected (${since.inMilliseconds}ms). Waiting ${waitMs}ms.');
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }

    if (_isDisposed) {
      debugPrint("[SocketService] connectAndListen çağrıldı ancak instance disposed durumda, işlem atlandı.");
      return;
    }

    if (_permanentAuthFailure) {
      debugPrint("[SocketService] connectAndListen: permanentAuthFailure aktif, connect atlanıyor.");
      NotificationCenter.instance.postNotification('auth_refresh_failed', {'reason': 'permanent_auth_failure_on_connect'});
      return;
    }

    if (UserSession.token.isEmpty) {
      debugPrint("[SocketService] Token bulunamadığı için socket bağlantısı kurulmuyor.");
      _setConnectionStatus('Bağlantı için token gerekli.');
      return;
    }

    // Token expiry kontrolü
    bool tokenExpired = false;
    try {
      tokenExpired = JwtDecoder.isExpired(UserSession.token);
    } catch (e) {
      debugPrint('[SocketService] JwtDecoder hata: $e - token expired varsayılıyor');
      tokenExpired = true;
    }
    
    // Token expired ise önce refresh et
    if (tokenExpired) {
      debugPrint('[SocketService] Token expired, refreshing before connect...');
      
      final refreshSuccess = await _attemptRefreshAndReconnect();
      if (!refreshSuccess) {
        debugPrint('[SocketService] Token refresh failed, cannot connect');
        _setConnectionStatus('Token yenilenemedi.');
        _isConnecting = false;
        _connectStartTime = null;
        _recordConnectionFailure(); // Failure kaydet
        return;
      }
      
      debugPrint('[SocketService] Token refreshed successfully, continuing with connection...');
    }

    // Mevcut bağlantı kontrolü
    if (_socket != null && _socket!.connected) {
      debugPrint("[SocketService] Zaten bağlı.");
      if (_currentKdsRoomSlug != null && UserSession.token.isNotEmpty) {
        joinKdsRoom(_currentKdsRoomSlug!);
      }
      return;
    }

    // Complete reset before new connection
    await _forceCompleteReset();

    _isConnecting = true;
    _connectStartTime = DateTime.now();

    debugPrint("[SocketService] 🚀 Starting fresh connection attempt");

    String baseSocketUrl = ApiService.baseUrl.replaceAll('/api', '');
    if (baseSocketUrl.endsWith('/')) {
      baseSocketUrl = baseSocketUrl.substring(0, baseSocketUrl.length - 1);
    }

    debugPrint("[SocketService] 🚀 Attempting to connect to: $baseSocketUrl");

    // Network connectivity check
    final connectivity = ConnectivityService.instance;
    if (!connectivity.isOnlineNotifier.value) {
      debugPrint("[SocketService] ❌ Network offline, aborting connection attempt");
      _setConnectionStatus('Network bağlantısı yok');
      _isConnecting = false;
      _connectStartTime = null;
      return;
    }

    // === GÜNCELLENMİŞ: Enhanced socket configuration with SSL error handling ===
    _socket = IO.io(
      baseSocketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setPath('/socket.io/')
          .setAuth({
            'token': UserSession.token,
            'refresh_token': UserSession.refreshToken,  // Refresh token support
          })
          .disableAutoConnect()
          .setTimeout(35000) // 30000->35000 artırıldı
          .setReconnectionAttempts(5) // 10->5 azaltıldı
          .setReconnectionDelay(3000) // 2000->3000 artırıldı
          .setReconnectionDelayMax(15000) // 10000->15000 artırıldı
          .setRandomizationFactor(0.3) // 0.5->0.3 azaltıldı
          .build(),
    );

    _registerListeners();
    
    try {
      if (_socket?.connected == false) {
        _socket!.connect();
        _startConnectTimeout();
      }
      debugPrint("[SocketService] Socket bağlantısı deneniyor: $baseSocketUrl");
      _startConnectWatchdog();
    } catch (e) {
      debugPrint("[SocketService] Socket connect hata: $e");
      _isConnecting = false;
      _connectStartTime = null;
      _clearConnectWatchdog();
      _clearConnectTimeout();
      _recordConnectionFailure(); // Failure kaydet
    }
  }

  void _disposeAndClearSocket() {
    debugPrint('[SocketService] _disposeAndClearSocket: mevcut socket güvenli şekilde temizleniyor.');
    
    _isConnecting = false;
    _isConnected = false;
    _connectStartTime = null;
    
    if (_socket != null) {
      try {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.dispose();
      } catch (e) {
        debugPrint('[SocketService] Socket dispose error (ignored): $e');
      }
      _socket = null;
    }
    
    _connectWatchdog?.cancel();
    _connectWatchdog = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectTimeout?.cancel();
    _connectTimeout = null;
  }

  void _registerNotificationListeners() {
    if (_socket == null) return;
    _socket!.on('new_order_notification', (data) {
      _handleNotification('new_order_notification', data);
    });
    _socket!.on('order_approved_for_kitchen', (data) {
      _handleNotification('order_approved_for_kitchen', data);
    });
    _socket!.on('order_ready_for_pickup_update', (data) {
      _handleNotification('order_ready_for_pickup_update', data);
    });
    _socket!.on('order_preparing_update', (data) {
      _handleNotification('order_preparing_update', data);
    });
    _socket!.on('order_pending_approval', (data) {
      _handleNotification('order_pending_approval', data);
    });
    _socket!.on('notification', (data) {
      _handleGeneralNotification(data);
    });
  }

  void _handleNotification(String type, dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        data['event_type'] = type;
        GlobalNotificationHandler.instance.addNotification(data);
      }
    } catch (e) {
      debugPrint('[SocketService] ❌ Notification handling error: $e');
    }
  }

  void _handleGeneralNotification(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        GlobalNotificationHandler.instance.addNotification(data);
      }
    } catch (e) {
      debugPrint('[SocketService] ❌ General notification handling error: $e');
    }
  }

  void _registerListeners() {
    if (_socket == null) return;
    
    try { _socket!.clearListeners(); } catch (_) {}
    
    _socket!.onConnect((_) {
      debugPrint("🔌 [SocketService] ✅ Fiziksel bağlantı başarıyla kuruldu. SID: ${_socket?.id}");
      _setConnectionStatus('Sunucu onayı bekleniyor...');
      _clearConnectTimeout();
      _registerNotificationListeners();
    });
    
    // Enhanced: connected_and_ready with token refresh support
    _socket!.on('connected_and_ready', (data) {
      debugPrint("✅ [SocketService] 'connected_and_ready' onayı alındı.");
      
      // Socket level token refresh support
      if (data is Map && data.containsKey('new_access_token')) {
        final String newAccessToken = data['new_access_token'];
        debugPrint("[SocketService] 🔄 Yeni access token alındı, güncelleniyor...");
        
        // Token'ı asenkron olarak güncelle
        UserSession.updateTokens(accessToken: newAccessToken).then((_) {
          debugPrint("[SocketService] ✅ Token güncelleme tamamlandı");
        }).catchError((e) {
          debugPrint("[SocketService] ❌ Token güncelleme hatası: $e");
        });
      }
      
      _setConnectionStatus('Bağlandı');
      _clearConnectWatchdog();
      _clearConnectTimeout();
      _isConnecting = false;
      _connectStartTime = null;
      _watchdogRetryCount = 0;
      _permanentAuthFailure = false;
      
      // === YENİ: Connection success durumunda failure count'u sıfırla ===
      _resetConnectionFailures();

      if (_currentKdsRoomSlug != null && UserSession.token.isNotEmpty) {
        joinKdsRoom(_currentKdsRoomSlug!);
      }

      debugPrint("[SocketService] 🔌 Bağlantı kuruldu/yenilendi. Genel veri yenileme tetikleniyor.");
      NotificationCenter.instance.postNotification('refresh_all_screens', {'eventType': 'socket_reconnected'});

      WidgetsBinding.instance.addPostFrameCallback((_) {
        shouldRefreshTablesNotifier.value = true;
        shouldRefreshWaitingCountNotifier.value = true;
        _processBackgroundQueue();
      });
      _addNotificationToHistory("Connection Successful", "system_connect");
    });
    
    _socket!.onDisconnect((reason) {
      debugPrint("🔌 [SocketService] Bağlantı koptu. Sebep: $reason");
      _setConnectionStatus('Bağlantı koptu. Tekrar deneniyor...');
      _addNotificationToHistory("Disconnect", "system_disconnect");

      _clearConnectWatchdog();
      _clearConnectTimeout();
      _isConnecting = false;
      _connectStartTime = null;

      // === YENİ: Sadece failure cooldown aktif değilse retry yap ===
      if (!_isInFailureCooldown()) {
        Future.delayed(Duration(seconds: 3 + Random().nextInt(4)), () { // 2+3 -> 3+4 arttırıldı
          if (!_isDisposed && (_socket == null || !_socket!.connected)) {
            debugPrint("[SocketService] Otomatik yeniden bağlanma deneniyor...");
            connectAndListen();
          }
        });
      } else {
        debugPrint("[SocketService] Otomatik reconnect atlandı - failure cooldown aktif.");
      }
    });
    
    // Enhanced: Connect error handling with socket level token refresh
    _socket!.onConnectError((data) {
      debugPrint("❌ [SocketService] onConnectError: $data");
      _setConnectionStatus('Bağlantı hatası - yeniden deneniyor...');
      _addNotificationToHistory("Bağlantı hatası.", "system_connect_error");

      _clearConnectWatchdog();
      _clearConnectTimeout();
      _isConnecting = false;
      _connectStartTime = null;
      
      // === YENİ: Connect error'da da failure kaydet ===
      _recordConnectionFailure();

      // Enhanced error analysis with socket level token refresh
      String errMsg = '';
      if (data is String) errMsg = data;
      else if (data is Map) {
        errMsg = data['message']?.toString() ?? data['detail']?.toString() ?? jsonEncode(data);
      } else {
        errMsg = data.toString();
      }
      
      final errLower = errMsg.toLowerCase();
      if ((errLower.contains('token') && (errLower.contains('expired') || errLower.contains('not valid') || errLower.contains('token_not_valid'))) ||
          errLower.contains('authentication') || errLower.contains('unauthorized') || errLower.contains('yetkisiz')) {
        debugPrint('[SocketService] Connect error indicates token problem -> attempt token refresh and reconnect');
        
        _attemptRefreshAndReconnect().then((refreshSuccess) {
          if (refreshSuccess && !_isInFailureCooldown()) {
            debugPrint('[SocketService] 🔄 Token refresh successful, reconnecting...');
            Timer(const Duration(seconds: 2), () { // 1->2 saniye artırıldı
              if (!_isDisposed && UserSession.token.isNotEmpty) {
                connectAndListen();
              }
            });
          } else {
            debugPrint('[SocketService] ❌ Token refresh failed on connect error or in cooldown');
          }
        });
      } else {
        // === YENİ: Sadece failure cooldown aktif değilse retry yap ===
        if (!_isInFailureCooldown()) {
          Timer(const Duration(seconds: 4), () { // 2->4 saniye artırıldı
            if (!_isDisposed && UserSession.token.isNotEmpty) {
              debugPrint("[SocketService] 🔄 Retrying after connect error...");
              connectAndListen();
            }
          });
        }
      }
    });
    
    _socket!.onError((data) {
      debugPrint("❗ [SocketService] Genel Hata: $data");
      _addNotificationToHistory("Sistem hatası.", "system_error");

      _clearConnectWatchdog();
      _clearConnectTimeout();
      _isConnecting = false;
      _connectStartTime = null;

      String errMsg = data?.toString() ?? '';
      final errLower = errMsg.toLowerCase();
      if ((errLower.contains('token') && errLower.contains('expired')) || errLower.contains('token_not_valid')) {
        _attemptRefreshAndReconnect();
      }
    });

    _socket!.on('order_status_update', (data) {
      if (data is! Map<String, dynamic>) return;
      final String? notificationId = data['notification_id'] as String?;
      final String? eventType = data['event_type'] as String?;

      if (!_shouldProcessNotification(notificationId, eventType)) {
        return;
      }

      final isKdsEvent = _isKdsEvent(eventType);
      final isMainScreenActive = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

      if (!isMainScreenActive) {
        if (isKdsEvent) {
          _priorityKdsEventQueue.add(Map<String, dynamic>.from(data));
        } else {
          _backgroundEventQueue.add(Map<String, dynamic>.from(data));
        }

        if (eventType != null && _loudNotificationEvents.contains(eventType) && UserSession.hasNotificationPermission(eventType)) {
          GlobalNotificationHandler.instance.addNotification(data);
        }
        return;
      }

      _processEventData(data, isPriorityKds: isKdsEvent);
    });

    _socket!.on('waiting_list_update', (data) {
      if (data is! Map<String, dynamic>) return;

      final String? eventType = data['event_type'] as String?;
      if (eventType == null || !UserSession.hasNotificationPermission(eventType)) {
        return;
      }

      _addNotificationToHistory(data['message'] ?? 'Bekleme listesi güncellendi.', eventType);
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
      if (data is Map<String, dynamic> && data['event_type'] == 'pager_status_updated') {
        _addNotificationToHistory(data['message'] ?? 'Pager durumu güncellendi.', 'pager_status_updated');
        pagerStatusUpdateNotifier.value = Map<String, dynamic>.from(data);
      }
    });

    _socket!.on('stock_alert', (data) {
      if (data is Map<String, dynamic> && data['alert'] is bool) {
        _addNotificationToHistory(data['message'] ?? 'Stok durumu güncellendi.', 'stock_adjusted');
        stockAlertNotifier.value = data['alert'];
      }
    });

    // === YENİ EKLENEN: STOCK EVENT LISTENER ===
    _socket!.on('stock_event', (data) {
      if (data is Map<String, dynamic>) {
        final String? eventType = data['event_type'] as String?;
        debugPrint("[SocketService] 📡 Stok olayı alındı: '$eventType'");
        
        // Stok olayı için notification history'ye ekle
        _addNotificationToHistory(
          data['message'] ?? 'Stok durumu güncellendi.', 
          eventType ?? 'stock_event'
        );
        
        // Bu olayı genel bir yenileme mekanizmasına bağlayabiliriz.
        // Örneğin, stok ekranının yenilenmesi gerektiğini bildirebiliriz.
        NotificationCenter.instance.postNotification('refresh_all_screens', {
          'eventType': eventType, 
          'data': data
        });
        
        // Özel stok bildirimi için de kullanılabilir
        NotificationCenter.instance.postNotification('stock_status_update', data);
      }
    });

    debugPrint("[SocketService] Tüm socket listener'ları kaydedildi.");
  }

  void _addNotificationToHistory(String message, String eventType) {
    final timeStampedMessage = '[${DateFormat('HH:mm:ss').format(DateTime.now())}] $message';
    final currentHistory = List<Map<String, String>>.from(notificationHistoryNotifier.value);
    currentHistory.insert(0, {'message': timeStampedMessage, 'eventType': eventType});
    if (currentHistory.length > 100) {
      currentHistory.removeLast();
    }
    notificationHistoryNotifier.value = currentHistory;
  }

  void joinKdsRoom(String kdsSlug) {
    _currentKdsRoomSlug = kdsSlug;
    if (_socket != null && _socket!.connected) {
      if (UserSession.token.isEmpty) {
        debugPrint("[SocketService] KDS odasına katılmak için token gerekli, ancak token yok.");
        return;
      }
      final payload = {'token': UserSession.token, 'kds_slug': kdsSlug};
      debugPrint("[SocketService] 'join_kds_room' eventi gönderiliyor. Slug: $kdsSlug");
      _socket!.emit('join_kds_room', payload);
    } else {
      debugPrint("[SocketService] Socket bağlı değil. KDS odasına katılım isteği bağlantı kurulunca yapılacak.");
      if (_socket?.connected == false && UserSession.token.isNotEmpty) {
        connectAndListen();
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
    _setConnectionStatus('Bağlantı bekleniyor...');
    _processedNotificationIds.clear();
    _lastEventTimes.clear();
    _backgroundEventQueue.clear();
    _priorityKdsEventQueue.clear();
    _watchdogRetryCount = 0;
    _permanentAuthFailure = false;
    
    // === YENİ: Failure count'u da resetle ===
    _consecutiveFailures = 0;
    _lastFailureTime = null;

    debugPrint("[SocketService] Servis durumu sıfırlandı.");
  }

  void disconnect() {
    if (_socket != null) {
      try {
        debugPrint("[SocketService] Disconnecting socket...");
        _socket!.disconnect();
      } catch (e) {
        debugPrint("[SocketService] disconnect error: $e");
      }
    }
  }

  @override
  void dispose() {
    debugPrint("[SocketService] Disposing...");
    _isDisposed = true;
    
    _isConnecting = false;
    _isConnected = false;
    _isRefreshingToken = false;
    _permanentAuthFailure = false;
    _watchdogRetryCount = 0;
    _connectionAttempts = 0;
    _connectStartTime = null;
    
    // === YENİ: Failure tracking temizle ===
    _consecutiveFailures = 0;
    _lastFailureTime = null;
    
    _connectWatchdog?.cancel();
    _connectWatchdog = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _periodicPingTimer?.cancel();
    _periodicPingTimer = null;
    _connectTimeout?.cancel();
    _connectTimeout = null;
    
    if (_socket != null) {
      debugPrint('[SocketService] Disconnecting socket...');
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (e) {
        debugPrint('[SocketService] Socket dispose error: $e');
      }
      _socket = null;
    }
    
    _processedNotificationIds.clear();
    _lastEventTimes.clear();
    _backgroundEventQueue.clear();
    _priorityKdsEventQueue.clear();
    
    try {
      connectionStatusNotifier.value = 'Bağlantı kesildi';
      connectionStatusNotifier.dispose();
    } catch (e) {
      debugPrint('[SocketService] connectionStatusNotifier dispose error: $e');
    }
    
    try {
      notificationHistoryNotifier.dispose();
    } catch (e) {
      debugPrint('[SocketService] notificationHistoryNotifier dispose error: $e');
    }
    
    debugPrint('[SocketService] Dispose completed - all resources cleaned');
    super.dispose();
  }

  void onScreenBecameActive() {
    debugPrint("[SocketService] 📱 Ekran aktif oldu, background queue işleniyor");
    _processBackgroundQueue();
    NotificationCenter.instance.postNotification('screen_became_active', {'timestamp': DateTime.now().toIso8601String()});
  }
}
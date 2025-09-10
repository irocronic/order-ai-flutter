// lib/main.dart
// Enhanced with network state tracking and improved socket connection management

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:makarna_app/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/connectivity_service.dart';
import 'services/cache_service.dart';
import 'services/sync_service.dart';
import 'services/global_notification_handler.dart' as globalHandler;
import 'services/connection_manager.dart';
import 'services/socket_service.dart';
import 'services/user_session.dart';
import 'services/notification_center.dart';
import 'models/sync_queue_item.dart';
import 'models/printer_config.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'dart:async';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

// Global Keys - Thundering Herd çözümü için RouteObserver eklendi
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// NavigatorSafeZone & BuildLockManager (özetlenmiş sürüm)
class NavigatorSafeZone {
  static bool _isNavigatorBusy = false;
  static int _operationCount = 0;
  static Timer? _busyTimer;
  static final Set<String> _activeOperations = <String>{};
  static bool _isNavigating = false;
  static bool get isBusy => _isNavigatorBusy;
  static bool get isNavigating => _isNavigating;
  static Set<String> get activeOperations => Set.from(_activeOperations);

  static void markBusy(String operation) {
    if (_activeOperations.contains(operation)) return;
    _activeOperations.add(operation);
    _operationCount++;
    _isNavigatorBusy = true;
    _busyTimer?.cancel();
    _busyTimer = Timer(const Duration(seconds: 3), () { forceUnlock('timeout'); });
  }
  static void markFree(String operation) {
    _activeOperations.remove(operation);
    _operationCount = _operationCount > 0 ? _operationCount - 1 : 0;
    if (_operationCount <= 0) {
      _operationCount = 0;
      _isNavigatorBusy = false;
      _activeOperations.clear();
      _busyTimer?.cancel();
    }
  }
  static void forceUnlock(String reason) {
    _isNavigatorBusy = false;
    _operationCount = 0;
    _activeOperations.clear();
    _busyTimer?.cancel();
  }
  static void setNavigating(bool navigating) {
    _isNavigating = navigating;
    if (!navigating && !_isNavigatorBusy) {
      Timer(const Duration(milliseconds: 50), () {
        try {
          globalHandler.GlobalNotificationHandler.instance.processPendingNotifications();
        } catch (_) {}
      });
    }
  }
  static bool canNavigate() => !_isNavigatorBusy && !_isNavigating;
  static void healthCheck() {}
}

class BuildLockManager {
  static bool _isBuildLocked = false;
  static final Set<String> _activeLocks = <String>{};
  static Timer? _unlockTimer;
  static bool get isLocked => _isBuildLocked;
  static Set<String> get activeLocks => Set.from(_activeLocks);
  static void lockBuild(String reason) {
    if (_activeLocks.contains(reason)) return;
    _activeLocks.add(reason);
    if (!_isBuildLocked) {
      _isBuildLocked = true;
      _unlockTimer?.cancel();
      _unlockTimer = Timer(const Duration(seconds: 2), () { forceUnlock('timeout'); });
    }
  }
  static void unlockBuild(String reason) {
    _activeLocks.remove(reason);
    if (_activeLocks.isEmpty && _isBuildLocked) { _isBuildLocked = false; _unlockTimer?.cancel(); }
  }
  static void forceUnlock(String reason) {
    _activeLocks.clear();
    _isBuildLocked = false;
    _unlockTimer?.cancel();
  }
  static bool shouldSkipBuild() => _isBuildLocked;
  static void healthCheck() {}
}

// Centralized logout
Future<void> performLogout() async {
  debugPrint('[GlobalLogout] Kapsamlı logout işlemi başlatılıyor...');
  try {
    // BLOCK initialization so no component can re-initialize socket/service while logout in progress
    SocketService.blockInitialization();

    ConnectionManager().stopMonitoring();
    globalHandler.GlobalNotificationHandler.cleanup();
    SocketService.disposeInstance();
    await UserSession.clearSession();
    await navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
    debugPrint('[GlobalLogout] Logout tamamlandı ve LoginScreen\'e yönlendirildi.');
  } catch (e) {
    debugPrint('❌ [GlobalLogout] Logout sırasında hata: $e');
  }
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();
  Hive.registerAdapter(SyncQueueItemAdapter());
  Hive.registerAdapter(PrinterConfigAdapter());
  // Servisleri başlat
  await CacheService.instance.initialize();
  ConnectivityService.instance.initialize();
  SyncService.instance.initialize();

  tz.initializeTimeZones();
  try {
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    print("Zaman dilimi alınamadı: $e");
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..loadLocale(),
      child: const MyApp(),
    ),
  );

  globalHandler.GlobalNotificationHandler.initialize();
  await Future.delayed(const Duration(seconds: 1));
  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isAppReady = false;
  
  // 🆕 Network state tracking variables
  late ConnectivityService _connectivityService;
  bool _lastKnownNetworkState = false;

  void Function(dynamic)? _authRefreshFailedListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 🆕 Initialize connectivity service and network tracking
    _connectivityService = ConnectivityService.instance;
    _lastKnownNetworkState = _connectivityService.isOnlineNotifier.value;
    _setupNetworkStateTracking();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isAppReady = true);
        globalHandler.GlobalNotificationHandler.updateAppLifecycleState(AppLifecycleState.resumed);
        ConnectionManager().startMonitoring();
        debugPrint('[MyApp] Connection manager başlatıldı');

        // auth_refresh_failed observer
        _authRefreshFailedListener = (dynamic payload) async {
          debugPrint('[MyApp] auth_refresh_failed alındı: $payload -> performLogout() çağrılıyor');
          try {
            await performLogout();
          } catch (e) {
            debugPrint('[MyApp] performLogout hata: $e');
          }
        };
        try {
          NotificationCenter.instance.addObserver('auth_refresh_failed', _authRefreshFailedListener!);
          debugPrint('[MyApp] auth_refresh_failed observer kaydedildi.');
        } catch (e) {
          debugPrint('[MyApp] auth_refresh_failed observer eklenirken hata: $e');
        }
      }
    });
  }

  // 🆕 ENHANCED: Network state tracking setup
  void _setupNetworkStateTracking() {
    _connectivityService.isOnlineNotifier.addListener(_onNetworkStateChanged);
    debugPrint('[MyApp] 🌐 Network state tracking initialized');
  }

  // 🆕 ENHANCED: Network state change handler
  void _onNetworkStateChanged() {
    final currentNetworkState = _connectivityService.isOnlineNotifier.value;
    
    if (currentNetworkState != _lastKnownNetworkState) {
      debugPrint('[MyApp] 🌐 Network state changed: ${_lastKnownNetworkState ? 'Online' : 'Offline'} -> ${currentNetworkState ? 'Online' : 'Offline'}');
      _lastKnownNetworkState = currentNetworkState;
      
      if (currentNetworkState) {
        // Network came back online
        _handleNetworkReconnected();
      } else {
        // Network went offline
        _handleNetworkDisconnected();
      }
    }
  }

  // 🆕 ENHANCED: Handle network reconnection
  void _handleNetworkReconnected() {
    debugPrint('[MyApp] 🌐✅ Network reconnected - checking socket status');
    
    // Delay to ensure network is stable
    Timer(const Duration(seconds: 2), () {
      if (UserSession.token.isNotEmpty) {
        final socket = SocketService.instance;
        debugPrint('[MyApp] 🔌 Socket state after network reconnection: connected=${socket.isConnected}');
        
        if (!socket.isConnected) {
          debugPrint('[MyApp] 🔄 Network available but socket disconnected, attempting reconnect...');
          socket.connectAndListen();
        }
        
        // Restart connection manager if not monitoring
        if (!ConnectionManager().isMonitoring) {
          debugPrint('[MyApp] 🔄 Restarting connection manager after network reconnection');
          ConnectionManager().startMonitoring();
        }
      }
    });
  }

  // 🆕 ENHANCED: Handle network disconnection
  void _handleNetworkDisconnected() {
    debugPrint('[MyApp] 🌐❌ Network disconnected');
    // Optionally handle offline state
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAppReady) return;
    super.didChangeAppLifecycleState(state);
    
    // 🆕 ENHANCED: Detailed app lifecycle logging
    debugPrint('[MyApp] 📱 App lifecycle state: $state');
    
    try {
      globalHandler.GlobalNotificationHandler.updateAppLifecycleState(state);
    } catch (e) {
      debugPrint('GlobalNotificationHandler lifecycle update failed: $e');
    }
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        debugPrint('[MyApp] Uygulama inactive durumda');
        NavigatorSafeZone.markBusy('app_inactive');
        BuildLockManager.lockBuild('app_inactive');
        break;
      case AppLifecycleState.resumed:
        debugPrint('[MyApp] Uygulama ön plana geldi, kilitler açılıyor ve bağlantılar kontrol ediliyor...');
        NavigatorSafeZone.markFree('app_resumed');
        Timer(const Duration(milliseconds: 300), () {
          BuildLockManager.unlockBuild('app_inactive');
        });
        Timer(const Duration(milliseconds: 800), () {
          try {
            globalHandler.GlobalNotificationHandler.instance.processPendingNotifications();
          } catch (e) {
            debugPrint('Failed to process pending notifications: $e');
          }
        });
        
        // 🆕 ENHANCED: App resume with network and socket checking
        Timer(const Duration(seconds: 1), () {
          _checkConnectionsAfterResume();
        });
        break;
      case AppLifecycleState.detached:
        debugPrint('[MyApp] Uygulama kapatıldı (detached)');
        NavigatorSafeZone.forceUnlock('app_detached');
        BuildLockManager.forceUnlock('app_detached');
        break;
      default:
        break;
    }
  }

  // 🆕 ENHANCED: Comprehensive connection checking after app resume
  Future<void> _checkConnectionsAfterResume() async {
    debugPrint("[MyApp] 🔄 Uygulama ön plana geldi, bağlantılar ve token kontrol ediliyor...");
    
    // 🆕 Network state check first
    final connectivity = ConnectivityService.instance;
    final isOnline = connectivity.isOnlineNotifier.value;
    debugPrint('[MyApp] 🌐 Network state on resume: ${isOnline ? "Online" : "Offline"}');
    
    if (!isOnline) {
      debugPrint('[MyApp] ❌ Network offline, skipping connection checks');
      return;
    }
    
    final token = UserSession.token;
    final refreshToken = UserSession.refreshToken;

    if (token.isEmpty || refreshToken.isEmpty) {
      debugPrint('[MyApp] Token bulunamadı, bağlantı kontrolü atlanıyor.');
      return;
    }

    bool isTokenExpired = false;
    try {
      isTokenExpired = JwtDecoder.isExpired(token);
      debugPrint("[MyApp] 🔑 Token expiry check: ${isTokenExpired ? 'Expired' : 'Valid'}");
    } catch (e) {
      debugPrint("[MyApp] Access token parse edilemedi, geçersiz/süresi dolmuş kabul ediliyor: $e");
      isTokenExpired = true;
    }

    final socketService = SocketService.instance;
    debugPrint('[MyApp] 🔌 Current socket state: connected=${socketService.isConnected}, connecting=${socketService.isConnecting}');

    if (isTokenExpired) {
      debugPrint("[MyApp] Access token süresi dolmuş, yenileme deneniyor...");
      try {
        final newTokens = await ApiService.refreshToken(refreshToken);
        final newAccessToken = newTokens['access'];
        final newRefreshToken = newTokens['refresh'];
        if (newAccessToken != null) {
          await UserSession.updateTokens(accessToken: newAccessToken, refreshToken: newRefreshToken);
          debugPrint("[MyApp] ✅ Token başarıyla yenilendi.");

          // 🆕 Enhanced socket reconnection after token refresh
          debugPrint("[MyApp] 🔄 Reconnecting socket after token refresh...");
          socketService.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));
          await socketService.connectAndListen();
        } else {
          throw Exception("Yenilenen token 'access' anahtarı içermiyor.");
        }
      } catch (e) {
        debugPrint('❌ [MyApp] Token yenileme başarısız, tam logout yapılıyor: $e');
        await performLogout();
        return;
      }
    } else {
      // Token is valid, check socket connection
      if (!socketService.isConnected && !socketService.isConnecting) {
        debugPrint('[MyApp] 🔄 Token geçerli, kopuk socket yeniden bağlanıyor...');
        await socketService.connectAndListen();
      } else if (socketService.isConnecting) {
        debugPrint('[MyApp] ⏳ Socket already attempting to connect...');
      } else {
        debugPrint('[MyApp] ✅ Socket already connected.');
      }
    }

    // 🆕 Enhanced connection manager check
    if (!ConnectionManager().isMonitoring) {
      debugPrint('[MyApp] 🔄 Starting connection manager monitoring...');
      ConnectionManager().startMonitoring();
    } else {
      debugPrint('[MyApp] ✅ Connection manager already monitoring.');
    }
    
    debugPrint("[MyApp] ✅ Connection check completed");
  }

  @override
  void dispose() {
    debugPrint('[MyApp] Dispose ediliyor...');
    WidgetsBinding.instance.removeObserver(this);

    // 🆕 Clean up network state tracking
    try {
      _connectivityService.isOnlineNotifier.removeListener(_onNetworkStateChanged);
      debugPrint('[MyApp] 🌐 Network state tracking cleaned up');
    } catch (e) {
      debugPrint('[MyApp] Network listener cleanup error: $e');
    }

    try {
      if (_authRefreshFailedListener != null) {
        NotificationCenter.instance.removeObserver('auth_refresh_failed', _authRefreshFailedListener!);
        debugPrint('[MyApp] auth_refresh_failed observer kaldırıldı.');
      }
    } catch (e) {
      debugPrint('[MyApp] auth_refresh_failed observer kaldırılırken hata: $e');
    }

    NavigatorSafeZone.forceUnlock('app_dispose');
    BuildLockManager.forceUnlock('app_dispose');

    ConnectionManager().stopMonitoring();
    SocketService.instance.dispose();
    globalHandler.GlobalNotificationHandler.instance.dispose();

    super.dispose();
    debugPrint('[MyApp] Dispose tamamlandı');
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    if (BuildLockManager.shouldSkipBuild()) {
      return MaterialApp(
        title: 'OrderAI',
        debugShowCheckedModeBanner: false,
        home: Container(
          color: Colors.blue.shade900,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Sistem hazırlanıyor...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'OrderAI',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      locale: languageProvider.currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', ''),
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
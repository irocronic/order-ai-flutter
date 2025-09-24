// lib/screens/business_owner_home.dart

import '../services/notification_center.dart';
import '../services/refresh_manager.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

// Servisler
import '../services/user_session.dart';
import '../services/socket_service.dart';
import '../services/connectivity_service.dart';
import '../services/global_notification_handler.dart' as globalHandler;
import '../services/connection_manager.dart';
import '../services/api_service.dart';
import '../services/business_owner_home_event_handler.dart';
import '../services/business_owner_home_state_manager.dart';
import '../services/shift_manager.dart';

// Modeller
import '../models/kds_screen_model.dart';
import '../models/notification_event_types.dart';

// Ekranlar
import 'login_screen.dart';

// Widget'lar
import '../widgets/shared/offline_banner.dart';
import '../widgets/shared/sync_status_indicator.dart';
import '../widgets/home/business_owner_app_bar.dart';
import '../widgets/home/business_owner_bottom_nav.dart';
import '../widgets/home/kds_navigation_handler.dart';

// Diğerleri
import '../utils/notifiers.dart';
import '../utils/tab_builder.dart';
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
    final BusinessOwnerHomeEventHandler _eventHandler = BusinessOwnerHomeEventHandler.instance;
    final BusinessOwnerHomeStateManager _stateManager = BusinessOwnerHomeStateManager.instance;
    final ShiftManager _shiftManager = ShiftManager.instance;

    String? _currentKdsRoomSlugForSocketService;

    @override
    void initState() {
        super.initState();
        debugPrint("[${DateTime.now()}] _BusinessOwnerHomeState: initState. User: ${UserSession.username}, Type: ${UserSession.userType}");
        
        WidgetsBinding.instance.addObserver(this);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
                _initializeAsyncDependencies();
            }
        });
    }

    @override
    void dispose() {
        debugPrint("[${DateTime.now()}] _BusinessOwnerHomeState: dispose.");
        routeObserver.unsubscribe(this);
        WidgetsBinding.instance.removeObserver(this);
        
        _eventHandler.dispose();
        _stateManager.dispose();
        _shiftManager.dispose();
        
        super.dispose();
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
        _eventHandler.safeRefreshDataWithThrottling();
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
            _eventHandler.safeRefreshDataWithThrottling();
        }
    }

    bool _shouldProcessUpdate() {
        return mounted && _isCurrent && _isAppInForeground;
    }

    Future<void> _safeRefreshDataAsync() async {
        if (!_shouldProcessUpdate()) return;
        await _stateManager.fetchActiveOrderCounts(widget.token, widget.businessId);
        await _stateManager.checkStockAlerts(widget.token);
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

    void _onStockAlertUpdate() {
        if (!_shouldProcessUpdate()) return;
        if (_stateManager.hasStockAlertsNotifier.value != stockAlertNotifier.value) {
            debugPrint("[BusinessOwnerHome] Stok uyarısı durumu güncellendi: ${stockAlertNotifier.value}");
            _stateManager.hasStockAlertsNotifier.value = stockAlertNotifier.value;
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
    
    Future<void> _initializeSocketConnection() async {
      try {
        debugPrint('[BusinessOwnerHome] Socket bağlantısı başlatılıyor...');
        
        if (UserSession.token.isEmpty) {
          debugPrint('[BusinessOwnerHome] ❌ Token empty, aborting socket connection');
          return;
        }
        
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
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        final socketService = SocketService.instance;
        final connectivity = ConnectivityService.instance;
        if (!connectivity.isOnlineNotifier.value) {
          debugPrint('[BusinessOwnerHome] ❌ Network offline, skipping socket connection');
          return;
        }
        
        debugPrint('[BusinessOwnerHome] 🌐 Network online, attempting socket connection...');
        
        int maxAttempts = 3;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          debugPrint('[BusinessOwnerHome] 🔄 Socket connection attempt $attempt/$maxAttempts');
          
          if (UserSession.token.isEmpty) {
            debugPrint('[BusinessOwnerHome] ❌ Token lost during attempt $attempt');
            return;
          }
          
          final connectFuture = socketService.connectAndListen();
          final timeoutFuture = Future.delayed(const Duration(seconds: 20));
          
          await Future.any([connectFuture, timeoutFuture]);
          await Future.delayed(const Duration(seconds: 2));
          
          if (socketService.isConnected) {
            debugPrint('[BusinessOwnerHome] ✅ Socket connection successful on attempt $attempt');
            return;
          }
          
          debugPrint('[BusinessOwnerHome] ❌ Socket connection failed on attempt $attempt');
          
          if (attempt < maxAttempts) {
            debugPrint('[BusinessOwnerHome] 🔄 Preparing for next attempt...');
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        }
        
        debugPrint('[BusinessOwnerHome] ❌ All socket connection attempts failed');
        
      } catch (e) {
        debugPrint('[BusinessOwnerHome] Socket başlatma hatası: $e');
      }
    }
    
    Future<void> _initializeAsyncDependencies() async {
        await _loadUserSessionIfNeeded();
        await _initializeSocketConnection();
        await _stateManager.fetchUserAccessibleKdsScreens(widget.token);
        
        _eventHandler.initialize(
          token: widget.token,
          businessId: widget.businessId,
          availableKdsScreens: _stateManager.availableKdsScreensNotifier.value,
          onOrderCountRefresh: () => _stateManager.fetchActiveOrderCounts(widget.token, widget.businessId),
          onStockAlertsCheck: () => _stateManager.checkStockAlerts(widget.token),
          onConnectivityChanged: _onConnectivityChanged,
          onSocketStatusUpdate: _updateSocketStatusFromService,
          onSyncStatusMessage: _handleSyncStatusMessage,
          onStockAlertUpdate: _onStockAlertUpdate,
          shouldProcessUpdate: _shouldProcessUpdate,
        );
        
        await _shiftManager.fetchAndMonitorShift(widget.token, () {
            if (mounted) {
                _shiftManager.showShiftEndDialog(context, _logout);
            }
        });

        _buildAndSetActiveTabs();
        await _stateManager.fetchActiveOrderCounts(widget.token, widget.businessId);
        _stateManager.startOrderCountRefreshTimer(() {
            if (_shouldProcessUpdate()) {
                _eventHandler.safeRefreshDataWithThrottling();
                _checkAndReconnectIfNeeded();
            }
        });
        await _stateManager.checkStockAlerts(widget.token);
        
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
    
    void _navigateToKdsScreen(BuildContext context) {
        KdsNavigationHandler.navigateToKdsScreen(
          context: context,
          token: widget.token,
          businessId: widget.businessId,
          availableKdsScreens: _stateManager.availableKdsScreensNotifier.value,
          isLoading: _stateManager.isLoadingKdsScreensNotifier.value,
          socketService: _socketService,
          onGoHome: () => _onNavBarTapped(0),
          onKdsRoomSelected: (slug) => _currentKdsRoomSlugForSocketService = slug,
        );
    }
    
    void _buildAndSetActiveTabs() {
        if (!mounted) return;
        
        TabBuilder.buildAndSetActiveTabs(
            context: context,
            token: widget.token,
            businessId: widget.businessId,
            onNavigateToKds: () => _navigateToKdsScreen(context),
            onTabChange: _onNavBarTapped,
            hasStockAlerts: _stateManager.hasStockAlertsNotifier.value,
            onTabsBuilt: (pages, navBarItems) {
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
            },
        );
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
                        _eventHandler.safeRefreshDataWithThrottling();
                    }
                });
            }
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
            // Navigate to KDS setup
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

    @override
    Widget build(BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        if (_activeTabPages.isEmpty &&
                !(UserSession.userType == 'customer' ||
                    UserSession.userType == 'admin')) {
            return Scaffold(
                appBar: BusinessOwnerAppBar(
                  socketService: _socketService,
                  shiftManager: _shiftManager,
                  onLogout: _logout,
                  onCheckConnection: _checkAndReconnectIfNeeded,
                  activeTabPages: _activeTabPages,
                  activeNavBarItems: _activeNavBarItems,
                  currentIndex: _currentIndex,
                  onBackToHome: _onNavBarTapped,
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

        return ValueListenableBuilder<bool>(
            valueListenable: _stateManager.hasStockAlertsNotifier,
            builder: (context, hasStockAlerts, child) {
                return Scaffold(
                    appBar: BusinessOwnerAppBar(
                      socketService: _socketService,
                      shiftManager: _shiftManager,
                      onLogout: _logout,
                      onCheckConnection: _checkAndReconnectIfNeeded,
                      activeTabPages: _activeTabPages,
                      activeNavBarItems: _activeNavBarItems,
                      currentIndex: safeCurrentIndex,
                      onBackToHome: _onNavBarTapped,
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
                    bottomNavigationBar: BusinessOwnerBottomNav(
                      activeNavBarItems: _activeNavBarItems,
                      currentIndex: safeCurrentIndex,
                      onTap: _onNavBarTapped,
                    ),
                );
            },
        );
    }
}
// lib/screens/business_owner_home.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:makarna_app/services/stock_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart'; // listEquals için

// Servisler
import '../services/user_session.dart';
import '../services/socket_service.dart';
import '../services/order_service.dart';
import '../services/kds_service.dart';
import '../services/kds_management_service.dart';
import '../services/connectivity_service.dart';

// Modeller
import '../models/kds_screen_model.dart';
import '../models/notification_event_types.dart';
import '../models/staff_permission_keys.dart';

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
    with RouteAware {
    int _currentIndex = 0;
    bool _isInitialLoadComplete = false;

    List<Widget> _activeTabPages = [];
    List<BottomNavigationBarItem> _activeNavBarItems = [];

    final SocketService _socketService = SocketService.instance;
    final ConnectivityService _connectivityService = ConnectivityService.instance;

    final ValueNotifier<int> _activeTableOrderCountNotifier = ValueNotifier(0);
    final ValueNotifier<int> _activeTakeawayOrderCountNotifier = ValueNotifier(0);
    final ValueNotifier<int> _activeKdsOrderCountNotifier = ValueNotifier(0);

    Timer? _orderCountRefreshTimer;

    List<KdsScreenModel> _availableKdsScreensForUser = [];
    bool _isLoadingKdsScreens = true;
    String? _currentKdsRoomSlugForSocketService;
    
    bool _hasStockAlerts = false;

    @override
    void initState() {
        super.initState();
        debugPrint("[${DateTime.now()}] _BusinessOwnerHomeState: initState. User: ${UserSession.username}, Type: ${UserSession.userType}");
        
        // --- İYİLEŞTİRME 1: Async işlemler build sonrası başlıyor ---
        // Bu, initState'in anında tamamlanmasını sağlar ve widget ağacı hazır olmadan
        // context gerektiren işlemlerin başlamasını engeller.
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeAsyncDependencies();
        });
        
        _addSocketServiceAndNotifierListeners();
    }

    @override
    void dispose() {
        debugPrint("[${DateTime.now()}] _BusinessOwnerHomeState: dispose.");
        routeObserver.unsubscribe(this);
        _removeSocketServiceAndNotifierListeners();
        _orderCountRefreshTimer?.cancel();
        _activeTableOrderCountNotifier.dispose();
        _activeTakeawayOrderCountNotifier.dispose();
        _activeKdsOrderCountNotifier.dispose();
        
        // SocketService.instance.dispose() çağrılmaz, çünkü uygulama boyunca yaşamalıdır.
        
        super.dispose();
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
    
    @override
    void didChangeDependencies() {
        super.didChangeDependencies();
        final route = ModalRoute.of(context);
        if (route is PageRoute) {
            routeObserver.subscribe(this, route);
        }
        
        if (ModalRoute.of(context)?.isCurrent == true && !_isInitialLoadComplete) {
            _fetchActiveOrderCounts().then((_) {
                if (mounted) {
                    setState(() { _isInitialLoadComplete = true; });
                }
            });
            _checkStockAlerts();
        }
    }

    @override
    void didPopNext() {
        super.didPopNext();
        debugPrint("BusinessOwnerHome: didPopNext - Ekran tekrar aktif oldu, veriler yenileniyor.");
        _fetchActiveOrderCounts();
        _checkStockAlerts();
    }
    
    @override
    void didPushNext() {
        debugPrint("BusinessOwnerHome: didPushNext - Ekran arka plana gidiyor.");
        super.didPushNext();
    }

    void _addSocketServiceAndNotifierListeners() {
        _connectivityService.isOnlineNotifier.addListener(_onConnectivityChanged);
        _socketService.connectionStatusNotifier.addListener(_updateSocketStatusFromService);
        
        orderStatusUpdateNotifier.addListener(_handleSilentOrderUpdates);
        shouldRefreshWaitingCountNotifier.addListener(_fetchActiveOrderCounts);
        syncStatusMessageNotifier.addListener(_handleSyncStatusMessage);
        stockAlertNotifier.addListener(_onStockAlertUpdate);
        debugPrint("[BusinessOwnerHome] Notifier listener'ları eklendi.");
    }

    void _removeSocketServiceAndNotifierListeners() {
        _connectivityService.isOnlineNotifier.removeListener(_onConnectivityChanged);
        _socketService.connectionStatusNotifier.removeListener(_updateSocketStatusFromService);
        
        orderStatusUpdateNotifier.removeListener(_handleSilentOrderUpdates);
        shouldRefreshWaitingCountNotifier.removeListener(_fetchActiveOrderCounts);
        syncStatusMessageNotifier.removeListener(_handleSyncStatusMessage);
        stockAlertNotifier.removeListener(_onStockAlertUpdate);
        debugPrint("[BusinessOwnerHome] Tüm notifier listener'ları kaldırıldı.");
    }

    void _onStockAlertUpdate() {
        if (!mounted) return;
        if (_hasStockAlerts != stockAlertNotifier.value) {
            debugPrint("[BusinessOwnerHome] Stok uyarısı durumu güncellendi: ${stockAlertNotifier.value}");
            setState(() {
                _hasStockAlerts = stockAlertNotifier.value;
            });
        }
    }
    
    void _handleSyncStatusMessage() {
        final message = syncStatusMessageNotifier.value;
        if (message != null && mounted) {
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
        if(mounted) {
            setState(() {
                debugPrint("BusinessOwnerHome: Connectivity changed. Rebuilding UI.");
            });
            if (_connectivityService.isOnlineNotifier.value) {
                _socketService.connectAndListen();
            }
        }
    }
    
    Future<void> _logout() async {
        _socketService.reset();
        UserSession.clearSession();
        if (mounted) {
            navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
            );
        }
    }
    
    Future<void> _initializeAsyncDependencies() async {
        await _loadUserSessionIfNeeded();
        _socketService.connectAndListen();
        await _fetchUserAccessibleKdsScreens();
        _buildAndSetActiveTabs();
        await _fetchActiveOrderCounts();
        _startOrderCountRefreshTimer();
        await _checkStockAlerts();
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
            if (mounted && ModalRoute.of(context)?.isCurrent == true) {
                _fetchActiveOrderCounts();
                _checkStockAlerts();
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
            }
        } catch (e) {
            debugPrint("Aktif sipariş sayıları çekilirken hata: $e");
        }
    }
    
    // === İYİLEŞTİRME 2: Daha Akıllı Bildirim İşleme ===
    void _handleSilentOrderUpdates() {
        final notificationData = orderStatusUpdateNotifier.value;
        // Bu metodun sadece bu ekran aktifken çalışmasını sağlıyoruz.
        if (notificationData != null && mounted && ModalRoute.of(context)!.isCurrent) {
            debugPrint("[BusinessOwnerHome] Anlık güncelleme alındı: ${notificationData['event_type']}");
            
            final eventType = notificationData['event_type'] as String?;
            
            // Sadece gerçekten sayaçları ve listeleri etkileyen bildirimlerde API'yi tekrar çağır.
            // Bu, gereksiz ağ trafiğini ve UI'ın sürekli titremesini engeller.
            if (eventType == NotificationEventTypes.guestOrderPendingApproval ||
                eventType == NotificationEventTypes.orderCancelledUpdate ||
                notificationData['is_paid_update'] == true) 
            {
                debugPrint("[BusinessOwnerHome] Sayaçları etkileyen bir olay geldi, sayılar yenileniyor.");
                _fetchActiveOrderCounts();
            }
        }
    }
    
    void _updateSocketStatusFromService() {
        if (mounted) {
            debugPrint("[BusinessOwnerHome] SocketService bağlantı durumu: ${_socketService.connectionStatusNotifier.value}");
            if (_socketService.connectionStatusNotifier.value == 'Bağlandı' && 
                _currentKdsRoomSlugForSocketService != null && 
                UserSession.token.isNotEmpty) {
                _socketService.joinKdsRoom(_currentKdsRoomSlugForSocketService!);
            }
        }
    }

    bool _canAccessTab(String permissionKey) {
        if (UserSession.userType == 'business_owner') return true;
        if (permissionKey == PermissionKeys.manageKds ||
            permissionKey == PermissionKeys.managePagers ||
            permissionKey == PermissionKeys.manageCampaigns ||
            permissionKey == PermissionKeys.manageKdsScreens) {
            return UserSession.userType == 'business_owner' || UserSession.hasPagePermission(permissionKey);
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
                                                    leading: Icon(Icons.desktop_windows_rounded, color: Colors.white70),
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
                        selectedLabelStyle:
                            const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                        unselectedLabelStyle: const TextStyle(fontSize: 10),
                        items: _activeNavBarItems,
                    ),
                )
                : null,
        );
    }
}
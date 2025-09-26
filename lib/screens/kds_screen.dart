// lib/screens/kds_screen.dart

import '../services/notification_center.dart';
import '../services/refresh_manager.dart';
import '../mixins/kds_recovery_mixin.dart';
import '../mixins/kds_dialog_mixin.dart';
import '../mixins/kds_button_action_mixin.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

import '../services/kds_service.dart';
import '../services/socket_service.dart';
import '../services/user_session.dart';
import '../widgets/kds/enhanced_kds_order_card.dart';
import '../utils/notifiers.dart';
import '../models/notification_event_types.dart';
import '../models/kds_screen_model.dart';
import '../main.dart';
import 'package:flutter/foundation.dart';

class KdsScreen extends StatefulWidget {
  final String token;
  final int businessId;
  final String kdsScreenSlug;
  final String kdsScreenName;
  final VoidCallback? onGoHome;
  final SocketService socketService;

  const KdsScreen({
    Key? key,
    required this.token,
    required this.businessId,
    required this.kdsScreenSlug,
    required this.kdsScreenName,
    this.onGoHome,
    required this.socketService,
  }) : super(key: key);

  @override
  _KdsScreenState createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen>
    with RouteAware,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin,
        KdsRecoveryMixin,
        KdsDialogMixin,
        KdsButtonActionMixin {
  
  List<dynamic> _kdsOrders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _refreshTimer;
  bool _isInitialLoadComplete = false;
  bool _isDisposed = false;
  bool _isNavigationInProgress = false;
  DateTime? _lastRefreshTime;
  
  // 🔥 YENİ: KDS Screen level action management
  final Map<String, bool> _screenActionStates = {};
  late OverlayEntry? _overlayEntry;

  // Screen state tracking
  bool _isCurrent = false;

  // NotificationCenter callback functions
  late Function(Map<String, dynamic>) _refreshAllScreensCallback;
  late Function(Map<String, dynamic>) _screenBecameActiveCallback;

  @override
  bool get wantKeepAlive => true;

  // Mixin implementations
  @override
  String get kdsScreenSlug => widget.kdsScreenSlug;
  
  @override
  SocketService get socketService => widget.socketService;
  
  @override
  bool get isDisposed => _isDisposed;
  
  @override
  bool get isCurrent => _isCurrent;
  
  @override
  DateTime? get lastRefreshTime => _lastRefreshTime;
  
  @override
  set lastRefreshTime(DateTime? value) => _lastRefreshTime = value;
  
  @override
  bool get isNavigationInProgress => _isNavigationInProgress;

  // KdsButtonActionMixin implementations
  @override
  String get token => widget.token;

  @override
  void onActionSuccess(String actionType, dynamic result) {
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] Action success: $actionType");
    _safeRefreshDataWithThrottling();
  }

  @override
  void onActionError(String actionType, String error) {
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] Action error [$actionType]: $error");
  }

  @override
  void showLoadingFeedback(String message) {
    _showOverlayFeedback(Colors.blue, Icons.hourglass_empty, message);
  }

  @override
  void showSuccessFeedback(String message) {
    _showOverlayFeedback(Colors.green, Icons.check_circle, message);
  }

  @override
  void showErrorFeedback(String message) {
    _showOverlayFeedback(Colors.red, Icons.error, message);
  }

  @override
  Future<void> fetchKdsOrders() async => _fetchKdsOrders();

  @override
  void leaveKdsRoom() => _leaveKdsRoom();

  @override
  void emergencyStopAllOperations() => _emergencyStopAllOperations();

  @override
  void safeRefreshDataWithThrottling() => _safeRefreshDataWithThrottling();

  @override
  void initState() {
    super.initState();
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] 🚀 initState with Enhanced Action Management");
    
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize overlay entry
    _overlayEntry = null;
    
    // Notifier listeners
    orderStatusUpdateNotifier.addListener(handleSocketOrderUpdate);
    newOrderNotificationDataNotifier.addListener(handleLoudNotification);

    // NotificationCenter listeners
    _refreshAllScreensCallback = (data) {
      if (!_isDisposed && mounted && shouldProcessUpdate()) {
        final eventType = data['eventType'] as String?;
        debugPrint("[KdsScreen-${widget.kdsScreenSlug}] 📡 Global refresh received: $eventType");
        _safeRefreshDataWithThrottling();
      }
    };

    _screenBecameActiveCallback = (data) {
      if (!_isDisposed && mounted && _isCurrent) {
        debugPrint("[KdsScreen-${widget.kdsScreenSlug}] 📱 Screen became active notification received");
        processPendingNotifications();
      }
    };

    NotificationCenter.instance.addObserver('refresh_all_screens', _refreshAllScreensCallback);
    NotificationCenter.instance.addObserver('screen_became_active', _screenBecameActiveCallback);

    // Initial setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint("[KdsScreen-${widget.kdsScreenSlug}] PostFrameCallback - Initialization completed.");
        joinKdsRoomWithStability();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
      debugPrint('[KdsScreen-${widget.kdsScreenSlug}] RouteObserver subscribed.');
    }
    
    if (!_isInitialLoadComplete) {
      debugPrint('[KdsScreen-${widget.kdsScreenSlug}] didChangeDependencies - Initial data fetch.');
      _fetchKdsOrdersWithLoadingIndicator();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] 🔄 dispose with enhanced cleanup");
    
    // Cleanup mixins
    disposeRecoveryMixin();
    disposeDialogMixin();
    disposeKdsButtonActionMixin();
    
    // Cleanup overlay
    _overlayEntry?.remove();
    _overlayEntry = null;
    
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    
    _refreshTimer?.cancel();
    
    orderStatusUpdateNotifier.removeListener(handleSocketOrderUpdate);
    newOrderNotificationDataNotifier.removeListener(handleLoudNotification);
    
    // NotificationCenter cleanup
    NotificationCenter.instance.removeObserver('refresh_all_screens', _refreshAllScreensCallback);
    NotificationCenter.instance.removeObserver('screen_became_active', _screenBecameActiveCallback);
    
    // Clear screen-level states
    _screenActionStates.clear();
    
    super.dispose();
  }

  // 🔥 Enhanced overlay feedback system
  void _showOverlayFeedback(Color color, IconData icon, String message) {
    _overlayEntry?.remove();
    
    if (!mounted) return;
    
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.95),
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(_overlayEntry!);
    
    Timer(const Duration(milliseconds: 2500), () {
      if (_overlayEntry != null && _overlayEntry!.mounted) {
        _overlayEntry!.remove();
        _overlayEntry = null;
      }
    });
  }

  void _emergencyStopAllOperations() {
    _isNavigationInProgress = false;
    isAppInForeground = false;
    dialogBlocked = true;
    isDialogShowing = false;
    activeDialogs.clear();
    isProcessingPending = false;
    recoveryInProgress = false;
    roomConnectionStable = false;
    
    // Clear screen action states
    _screenActionStates.clear();
    
    // Stop all timers
    cancelAllRecoveryTimers();
    dialogBlockTimer?.cancel();
    _refreshTimer?.cancel();
    roomStabilityTimer?.cancel();
    
    NavigatorSafeZone.markBusy('emergency_stop');
    
    debugPrint('[KdsScreen-${widget.kdsScreenSlug}] 🛑 Emergency stop - all operations halted');
  }

  void _leaveKdsRoom() {
    if (isJoinedToRoom) {
      isJoinedToRoom = false;
      roomConnectionStable = false;
      roomStabilityTimer?.cancel();
      debugPrint('[KdsScreen-${widget.kdsScreenSlug}] 👋 Left KDS room.');
    }
  }

  void _safeRefreshDataWithThrottling() {
    if (_isNavigationInProgress || _isDisposed || !mounted) return;
    
    if (shouldProcessUpdate()) {
      final refreshKey = 'kds_screen_${widget.kdsScreenSlug}';
      RefreshManager.throttledRefresh(refreshKey, () async {
        await _fetchKdsOrders();
      });
    }
  }

  // RouteAware methods
  @override
  void didPush() {
    _isCurrent = true;
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] ➡️ didPush - Screen pushed.");
    joinKdsRoomWithStability();
    super.didPush();
  }

  @override
  void didPopNext() {
    if (_isDisposed) return;
    _isCurrent = true;
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] ⬅️ didPopNext - Screen returned to foreground.");
    
    unblockDialogs();
    
    // PostFrameCallback for data refresh check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        if (roomConnectionStable) {
          // If we were away for long time, refresh data
          if (needsDataRefreshOnResume) {
            debugPrint('[KdsScreen-${widget.kdsScreenSlug}] 🔄 didPopNext - refreshing stale data');
            forceFreshDataRefresh();
            needsDataRefreshOnResume = false;
          } else {
            _safeRefreshDataWithThrottling();
          }
          processPendingNotifications();
        } else {
          joinKdsRoomWithStability();
        }
      }
    });
    super.didPopNext();
  }

  @override
  void didPushNext() {
    if (_isDisposed) return;
    _isCurrent = false;
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] ⏭️ didPushNext - Screen pushed to background.");
    _isNavigationInProgress = false;
    blockDialogsTemporarily();
    
    // Navigation background tracking
    needsDataRefreshOnResume = true;
    
    super.didPushNext();
  }

  @override
  void didPop() {
    if (_isDisposed) return;
    _isCurrent = false;
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] ⬅️ didPop - Screen is being popped.");
    _leaveKdsRoom();
    cleanupDialogs();
    super.didPop();
  }

  void _safeNavigate(VoidCallback navigationAction) {
    if (_isNavigationInProgress || _isDisposed || !mounted ||
        !NavigatorSafeZone.canNavigate() || BuildLockManager.isLocked) {
      debugPrint('[KDS] Navigation blocked - system busy');
      return;
    }
    
    _isNavigationInProgress = true;
    NavigatorSafeZone.markBusy('kds_navigation');
    
    try {
      navigationAction();
    } catch (e) {
      debugPrint("Navigation error in KDS: $e");
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _isNavigationInProgress = false;
          NavigatorSafeZone.markFree('kds_navigation');
        }
      });
    }
  }

  Future<void> _fetchKdsOrdersWithLoadingIndicator() async {
    if (!mounted || _isDisposed) return;
    
    // 🔥 Check if refresh action can be performed
    final refreshActionKey = 'refresh_${widget.kdsScreenSlug}';
    if (!canPerformAction(refreshActionKey)) {
      debugPrint('[KdsScreen-${widget.kdsScreenSlug}] 🚫 Refresh blocked - too frequent');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    await _fetchKdsOrders();
    
    if (mounted && !_isDisposed) {
      setState(() {
        _isLoading = false;
        if (!_isInitialLoadComplete) _isInitialLoadComplete = true;
      });
    }
  }

  Future<void> _fetchKdsOrders() async {
    if (!mounted || _isDisposed) return;
    final l10n = AppLocalizations.of(context)!;
    
    try {
      debugPrint('[KdsScreen-${widget.kdsScreenSlug}] 📦 Fetching KDS orders...');
      
      final orders = await KdsService.fetchKDSOrders(widget.token, widget.kdsScreenSlug).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('KDS orders fetch timeout', const Duration(seconds: 15)),
      );
      
      if (mounted && !_isDisposed) {
        setState(() {
          _kdsOrders = orders;
          _errorMessage = '';
        });
        debugPrint('[KdsScreen-${widget.kdsScreenSlug}] ✅ KDS orders updated (${orders.length} orders)');
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _errorMessage = l10n.kdsScreenErrorFetching(e.toString().replaceFirst("Exception: ", ""));
          _kdsOrders = [];
        });
      }
      debugPrint("[KdsScreen-${widget.kdsScreenSlug}] ❌ Error fetching KDS orders: $_errorMessage");
    }
  }

  // 🔥 Enhanced refresh button with action management
  void _handleRefreshButton() {
    final l10n = AppLocalizations.of(context)!;
    final refreshActionKey = 'manual_refresh_${widget.kdsScreenSlug}';
    
    if (!canPerformAction(refreshActionKey)) {
      _showOverlayFeedback(
        Colors.orange, 
        Icons.warning, 
        l10n.kdsScreenWaitForRefresh
      );
      return;
    }
    
    handleKdsAction(
      actionKey: refreshActionKey,
      actionType: 'refresh_orders',
      parameters: {},
      loadingMessage: l10n.kdsScreenRefreshingOrders,
      successMessage: l10n.kdsScreenOrdersUpdated,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Added early exit for context safety
    if (!mounted) {
      return Container(color: Colors.blueGrey.shade900);
    }
    
    final l10n = AppLocalizations.of(context)!;
    
    if (_isDisposed) {
      return Scaffold(
        backgroundColor: Colors.blueGrey.shade900,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                l10n.kdsScreenClosing,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (screenWidth > 1400) {
      crossAxisCount = 5;
    } else if (screenWidth > 1100) {
      crossAxisCount = 4;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
    } else if (screenWidth > 550) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kdsScreenTitle(widget.kdsScreenName),
            style: const TextStyle(fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blueGrey.shade800,
        leading: widget.onGoHome != null
            ? IconButton(
                icon: const Icon(Icons.home_outlined, color: Colors.white),
                tooltip: l10n.kdsScreenTooltipGoHome,
                onPressed: () {
                  _safeNavigate(() {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    widget.onGoHome!();
                  });
                },
              )
            : (Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: l10n.kdsScreenTooltipBack,
                    onPressed: () => _safeNavigate(() => Navigator.pop(context)),
                  )
                : null),
        actions: [
          ValueListenableBuilder<String>(
            valueListenable: widget.socketService.connectionStatusNotifier,
            builder: (context, status, child) {
              Color indicatorColor;
              IconData indicatorIcon;
              
              if (status == 'Bağlandı' && roomConnectionStable) {
                indicatorColor = Colors.green;
                indicatorIcon = Icons.wifi;
              } else if (status.contains('bekleniyor') || status.contains('deneniyor') || isJoinedToRoom) {
                indicatorColor = Colors.orange;
                indicatorIcon = Icons.wifi_tethering;
              } else {
                indicatorColor = Colors.red;
                indicatorIcon = Icons.wifi_off;
              }
              
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: joinKdsRoomWithStability,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: indicatorColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Icon(
                          indicatorIcon,
                          color: indicatorColor,
                          size: 16,
                        ),
                        // Pending notification indicator
                        if (pendingNotifications.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  '${pendingNotifications.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Dialog block indicator
                        if (dialogBlocked || BuildLockManager.isLocked || NavigatorSafeZone.isBusy)
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        // Processing indicator
                        if (isProcessingPending)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        // Data staleness indicator
                        if (needsDataRefreshOnResume)
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        // Recovery indicator
                        if (recoveryInProgress)
                          Positioned(
                            bottom: 0,
                            right: 4,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // 🔥 Enhanced refresh button
          Builder(
            builder: (context) {
              final refreshActionKey = 'manual_refresh_${widget.kdsScreenSlug}';
              final isRefreshing = isActionProcessing(refreshActionKey);
              
              if (isRefreshing) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: buildEnhancedLoadingIndicator(
                    color: Colors.white,
                    message: l10n.kdsScreenRefreshing,
                    size: 24,
                  ),
                );
              }
              
              return IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: l10n.kdsScreenTooltipRefresh,
                onPressed: _isLoading ? null : _handleRefreshButton,
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.blueGrey.shade900,
        child: (_isLoading && !_isInitialLoadComplete)
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty && _kdsOrders.isEmpty
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.orangeAccent.shade100, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(
                              color: Colors.orangeAccent, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.kdsScreenButtonRetry),
                          onPressed: _handleRefreshButton,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent.shade100,
                              foregroundColor: Colors.black87),
                        )
                      ],
                    ),
                  ))
                : _kdsOrders.isEmpty
                    ? Center(
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.kitchen_outlined,
                              size: 80, color: Colors.grey.shade500),
                          const SizedBox(height: 16),
                          Text(
                            l10n.kdsScreenNoOrders,
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.kdsScreenTooltipRefresh),
                            onPressed: _handleRefreshButton,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade50,
                              foregroundColor: Colors.blueGrey.shade900,
                            ),
                          )
                        ],
                      ))
                    : RefreshIndicator(
                        onRefresh: _fetchKdsOrders,
                        color: Colors.white,
                        backgroundColor: Colors.blueGrey.shade700,
                        child: MasonryGridView.count(
                          padding: const EdgeInsets.all(10),
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          itemCount: _kdsOrders.length,
                          itemBuilder: (context, index) {
                            final order = _kdsOrders[index];
                            return EnhancedKdsOrderCard( // 🔥 Updated to use enhanced card
                              key: ValueKey(order['id']),
                              orderData: order,
                              token: widget.token,
                              isLoadingAction: _isLoading,
                              onOrderUpdated: _fetchKdsOrders,
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
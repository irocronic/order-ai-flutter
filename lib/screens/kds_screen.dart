// lib/screens/kds_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

import '../services/kds_service.dart';
import '../services/socket_service.dart';
import '../services/user_session.dart';
import '../widgets/kds/kds_order_card.dart';
import '../widgets/dialogs/order_approved_for_kitchen_dialog.dart';
import '../widgets/dialogs/order_ready_for_pickup_dialog.dart';
import '../utils/notifiers.dart';
import '../models/notification_event_types.dart';
import '../models/kds_screen_model.dart';
import '../main.dart'; // routeObserver için
import 'package:flutter/foundation.dart'; // debugPrint için

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

class _KdsScreenState extends State<KdsScreen> with RouteAware {
  List<dynamic> _kdsOrders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _refreshTimer;
  bool _isInitialLoadComplete = false;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] initState");
    orderStatusUpdateNotifier.addListener(_handleSocketOrderUpdate);
    newOrderNotificationDataNotifier.addListener(_handleLoudNotification);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.socketService.joinKdsRoom(widget.kdsScreenSlug);
        debugPrint(
            "[KdsScreen-${widget.kdsScreenSlug}] Joined KDS room via initState/addPostFrameCallback.");
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
    debugPrint('[KdsScreen-${widget.kdsScreenSlug}] RouteObserver subscribed.');
    
    if (!_isInitialLoadComplete) {
      debugPrint('[KdsScreen-${widget.kdsScreenSlug}] didChangeDependencies - Initial data fetch.');
      _fetchKdsOrdersWithLoadingIndicator();
    }
  }

  @override
  void dispose() {
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] dispose");
    routeObserver.unsubscribe(this);
    _refreshTimer?.cancel();
    orderStatusUpdateNotifier.removeListener(_handleSocketOrderUpdate);
    newOrderNotificationDataNotifier.removeListener(_handleLoudNotification);
    super.dispose();
  }

  @override
  void didPush() {
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] didPush - Screen pushed.");
    super.didPush();
  }

  @override
  void didPopNext() {
    debugPrint("[KdsScreen-${widget.kdsScreenSlug}] didPopNext - Screen re-activated, refreshing data.");
    _fetchKdsOrders();
    super.didPopNext();
  }

  @override
  void didPushNext() {
      debugPrint("[KdsScreen-${widget.kdsScreenSlug}] didPushNext - Screen is being covered.");
      super.didPushNext();
  }

  @override
  void didPop() {
      debugPrint("[KdsScreen-${widget.kdsScreenSlug}] didPop - Screen is being popped.");
      super.didPop();
  }

  void _handleLoudNotification() {
    final data = newOrderNotificationDataNotifier.value;
    final context = navigatorKey.currentContext;

    if (data == null || context == null || _isDialogShowing) {
      if (data != null) newOrderNotificationDataNotifier.value = null;
      return;
    }

    final String? eventType = data['event_type'] as String?;
    if (eventType == null || !UserSession.hasNotificationPermission(eventType)) {
      newOrderNotificationDataNotifier.value = null;
      return;
    }
    
    final String? kdsSlugInEvent = data['kds_slug'] as String?;
    if (kdsSlugInEvent != null && kdsSlugInEvent != widget.kdsScreenSlug) {
      newOrderNotificationDataNotifier.value = null;
      return;
    }
    
    Widget? dialogWidget;
    switch (eventType) {
      case NotificationEventTypes.orderApprovedForKitchen:
        dialogWidget = OrderApprovedForKitchenDialog(notificationData: data, onAcknowledge: () {});  
        break;
      case NotificationEventTypes.orderReadyForPickupUpdate:
        dialogWidget = OrderReadyForPickupDialog(notificationData: data, onAcknowledge: () {});
        break;
      case NotificationEventTypes.orderItemAdded:
        dialogWidget = OrderApprovedForKitchenDialog(notificationData: data, onAcknowledge: () {});
        break;
    }

    if (dialogWidget != null) {
      _isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => dialogWidget!,
      ).then((_) {
        if (mounted) _isDialogShowing = false;
        shouldRefreshTablesNotifier.value = true;
        debugPrint("[GlobalNotificationHandler] Dialog kapatıldı, shouldRefreshTablesNotifier tetiklendi.");
      });
    }
    
    newOrderNotificationDataNotifier.value = null;
  }

  void _handleSocketOrderUpdate() {
    final data = orderStatusUpdateNotifier.value;
    if (data != null && mounted) {
      final String? eventType = data['event_type'] as String?;
      final String? kdsSlugInEvent = data['kds_slug'] as String?;

      // Sipariş iptali gibi genel bir olay geldiğinde (kds_slug içermeyebilir) 
      // VEYA bu KDS ekranını ilgilendiren bir olay geldiğinde yenileme yap.
      if (kdsSlugInEvent == null || kdsSlugInEvent == widget.kdsScreenSlug) {
        debugPrint("[KdsScreen-${widget.kdsScreenSlug}] Relevant socket update received: '$eventType'. Refreshing data...");
        _fetchKdsOrders();
      } else {
        debugPrint("[KdsScreen-${widget.kdsScreenSlug}] Event for other KDS ('$kdsSlugInEvent'), ignoring UI update for this screen.");
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && orderStatusUpdateNotifier.value == data) {
          orderStatusUpdateNotifier.value = null;
        }
      });
    }
  }

  Future<void> _fetchKdsOrdersWithLoadingIndicator() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    await _fetchKdsOrders();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!_isInitialLoadComplete) _isInitialLoadComplete = true;
      });
    }
  }

  Future<void> _fetchKdsOrders() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final orders =
          await KdsService.fetchKDSOrders(widget.token, widget.kdsScreenSlug);
      if (mounted) {
        setState(() {
          _kdsOrders = orders;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.kdsScreenErrorFetching(e.toString().replaceFirst("Exception: ", ""));
          _kdsOrders = [];
        });
      }
      debugPrint(
          "[KdsScreen-${widget.kdsScreenSlug}] Error fetching KDS orders: $_errorMessage");
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  widget.onGoHome!();
                },
              )
            : (Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: l10n.kdsScreenTooltipBack,
                    onPressed: () => Navigator.pop(context),
                  )
                : null),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: l10n.kdsScreenTooltipRefresh,
            onPressed: _isLoading ? null : _fetchKdsOrdersWithLoadingIndicator,
          )
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
                          onPressed: _fetchKdsOrdersWithLoadingIndicator,
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
                            onPressed: _fetchKdsOrdersWithLoadingIndicator,
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
                            return KdsOrderCard(
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
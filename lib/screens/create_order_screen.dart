// lib/screens/create_order_screen.dart

import '../services/notification_center.dart';
import '../services/refresh_manager.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../controllers/create_order_controller.dart';
import '../widgets/create_order/dialogs/create_order_dialogs.dart';
import '../widgets/waiting_customers_modal.dart';
import '../widgets/create_order/waiting_customer_button.dart';
import '../widgets/create_order/tables_grid_view.dart';
import '../widgets/dialogs/new_order_notification_dialog.dart';
import 'edit_order_screen.dart';
import 'new_order_screen.dart';
import '../utils/notifiers.dart';
import '../main.dart';
import '../services/user_session.dart';
import '../models/notification_event_types.dart';
import '../widgets/create_order/dialogs/table_order_details_modal.dart';

class CreateOrderScreen extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onGoHome;
  const CreateOrderScreen({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onGoHome,
  }) : super(key: key);
  @override
  _CreateOrderScreenState createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> with RouteAware {
  CreateOrderController? _controller;
  bool _isInitialLoadComplete = false;
  bool _isNotificationDialogShowing = false;

  bool _isCurrent = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[CreateOrderScreen] initState');
    shouldRefreshTablesNotifier.addListener(_onShouldRefreshTables);
    newOrderNotificationDataNotifier.addListener(_handleShowNotificationDialogIfNeeded);
    orderStatusUpdateNotifier.addListener(_handleSilentOrderUpdates);
    debugPrint('[CreateOrderScreen] Notifier listenerları eklendi.');
    NotificationCenter.instance.addObserver('refresh_all_screens', (data) {
      debugPrint('[CreateOrderScreen] 📡 Global refresh received: ${data['event_type']}');
      if (mounted) {
        _controller?.refreshData();
      }
    });
    NotificationCenter.instance.addObserver('screen_became_active', (data) {
      debugPrint('[CreateOrderScreen] 📱 Screen became active notification received');
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _controller?.refreshData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('[CreateOrderScreen] didChangeDependencies');
    if (_controller == null) {
      final l10n = AppLocalizations.of(context)!;
      debugPrint('[CreateOrderScreen] Controller atandı.');
      _controller = CreateOrderController(
        token: widget.token,
        businessId: widget.businessId,
        l10n: l10n,
        onStateUpdate: (VoidCallback fn) {
          debugPrint('[CreateOrderScreen] Controller onStateUpdate çağrıldı.');
          if (mounted) {
            setState(fn);
          }
        },
        showSnackBarCallback: (String message, {bool isError = false}) {
           debugPrint('[CreateOrderScreen] showSnackBarCallback: $message, isError: $isError');
           if (mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: isError ? Colors.redAccent : Colors.green,
                 duration: Duration(seconds: isError ? 4 : 2),
              ),
            );
          }
        },
        showDialogCallback: (Widget dialogContent) {
          debugPrint('[CreateOrderScreen] showDialogCallback çağrıldı.');
          if (mounted && !_isNotificationDialogShowing) {
            _isNotificationDialogShowing = true;
            showDialog(context: context, builder: (_) => dialogContent, barrierDismissible: false)
                .then((_) { 
                  debugPrint('[CreateOrderScreen] showDialogCallback dialog kapandı.');
                  if (mounted) _isNotificationDialogShowing = false; 
                });
          }
        },
        showModalBottomSheetCallback: (Widget modalContent) {
          debugPrint('[CreateOrderScreen] showModalBottomSheetCallback çağrıldı.');
          if (mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              enableDrag: false,
               backgroundColor: Colors.transparent,
              builder: (_) => modalContent,
            );
          }
        },
        navigateToScreenCallback: (Widget screen) {
          debugPrint('[CreateOrderScreen] navigateToScreenCallback çağrıldı.');
          if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
        popScreenCallback: (bool success) {
          debugPrint('[CreateOrderScreen] popScreenCallback çağrıldı: $success');
          if (mounted) Navigator.pop(context, success);
        },
        popUntilFirstCallback: () {
          debugPrint('[CreateOrderScreen] popUntilFirstCallback çağrıldı.');
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        },
      );
      debugPrint('[CreateOrderScreen] Controller oluşturuldu.');
    }

    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      debugPrint('[CreateOrderScreen] routeObserver.subscribe');
      routeObserver.subscribe(this, route);
    }

    if (ModalRoute.of(context)?.isCurrent == true) {
      debugPrint('[CreateOrderScreen] ModalRoute.isCurrent == true');
      if (!_isInitialLoadComplete) {
        debugPrint('[CreateOrderScreen] Initial load başlıyor.');
        _controller!.refreshData().then((_) {
          debugPrint('[CreateOrderScreen] Initial load tamamlandı.');
          if (mounted) {
            setState(() { _isInitialLoadComplete = true; });
            _checkAndHandlePendingNotifications();
          }
        });
      } else {
        _checkAndHandlePendingNotifications();
      }
    }
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _isCurrent = true;
    debugPrint('[CreateOrderScreen] didPopNext - Ekran tekrar aktif oldu.');
    _checkAndHandlePendingNotifications();
  }
  
  @override
  void didPushNext() {
    _isCurrent = false;
    debugPrint("[CreateOrderScreen] didPushNext - Ekran arka plana gitti.");
    super.didPushNext();
  }

  @override
  void didPop() {
    _isCurrent = false;
    debugPrint("[CreateOrderScreen] didPop - Ekran kapatıldı.");
    routeObserver.unsubscribe(this);
    super.didPop();
  }

  @override
  void didPush() {
    _isCurrent = true;
    debugPrint('[CreateOrderScreen] didPush çağrıldı.');
    _checkAndHandlePendingNotifications();
    super.didPush();
  }

  @override
  void dispose() {
    debugPrint('[CreateOrderScreen] dispose');
    shouldRefreshTablesNotifier.removeListener(_onShouldRefreshTables);
    newOrderNotificationDataNotifier.removeListener(_handleShowNotificationDialogIfNeeded);
    orderStatusUpdateNotifier.removeListener(_handleSilentOrderUpdates);
    _controller?.dispose();
    super.dispose();
  }

  void _onShouldRefreshTables() {
    debugPrint('[CreateOrderScreen] _onShouldRefreshTables tetiklendi.');
    if (shouldRefreshTablesNotifier.value && mounted) {
      _handleRefreshFromNotifier();
    }
  }

  void _handleRefreshFromNotifier() {
    debugPrint('[CreateOrderScreen] _handleRefreshFromNotifier tetiklendi.');
    if (!mounted) return;
    _controller!.refreshData().whenComplete(() {
      debugPrint('[CreateOrderScreen] _handleRefreshFromNotifier tamamlandı.');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && shouldRefreshTablesNotifier.value) {
            shouldRefreshTablesNotifier.value = false;
            debugPrint('[CreateOrderScreen] shouldRefreshTablesNotifier false yapıldı.');
          }
        });
      }
    });
  }

  void _handleShowNotificationDialogIfNeeded() {
    debugPrint('[CreateOrderScreen] _handleShowNotificationDialogIfNeeded çağrıldı.');
    if (newOrderNotificationDataNotifier.value != null &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true &&
        !_isNotificationDialogShowing) {
      final data = newOrderNotificationDataNotifier.value!;
      final String? eventType = data['event_type'] as String?;
      debugPrint('[CreateOrderScreen] Notification data var: eventType: $eventType');

      if (eventType == null || !UserSession.hasNotificationPermission(eventType)) {
        newOrderNotificationDataNotifier.value = null;
        debugPrint('[CreateOrderScreen] Notification permission yok veya eventType null.');
        return;
      }

      bool showDialogForThisEvent = false;
      if (eventType == NotificationEventTypes.guestOrderPendingApproval ||
          eventType == NotificationEventTypes.existingOrderNeedsReapproval ||
          (eventType == 'new_order' && data['status'] == 'pending_approval') ||
          eventType == NotificationEventTypes.newApprovedOrder) {
        showDialogForThisEvent = true;
      }

      if (showDialogForThisEvent) {
        debugPrint('[CreateOrderScreen] showDialogForThisEvent: $eventType');
        _isNotificationDialogShowing = true;
        showDialog(
          context: navigatorKey.currentContext ?? context,
          barrierDismissible: false,
          builder: (dialogContext) => NewOrderNotificationDialog(
            notificationData: data,
            onAcknowledge: () {
              debugPrint('[CreateOrderScreen] showDialogCallback onAcknowledge');
              _controller!.refreshData();
            },
          ),
        ).then((_) {
          debugPrint('[CreateOrderScreen] showDialogCallback then, dialog kapandı.');
          if (mounted) _isNotificationDialogShowing = false;
        });
      }
      newOrderNotificationDataNotifier.value = null;
    }
  }

  void _handleSilentOrderUpdates() {
    debugPrint('[CreateOrderScreen] _handleSilentOrderUpdates çağrıldı.');
    if (orderStatusUpdateNotifier.value != null && mounted) {
      debugPrint('[CreateOrderScreen] orderStatusUpdateNotifier.value != null');
      if (!_isCurrent) {
        debugPrint("[CreateOrderScreen] Ekran aktif değil, anlık yenileme atlandı.");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            orderStatusUpdateNotifier.value = null;
            debugPrint('[CreateOrderScreen] orderStatusUpdateNotifier.value null yapıldı.');
          }
        });
        return;
      }

      final refreshKey = 'create_order_screen_${widget.businessId}';
      RefreshManager.throttledRefresh(refreshKey, () async {
        debugPrint('[CreateOrderScreen] throttledRefresh tetiklendi.');
        await _controller?.refreshData();
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) {
          orderStatusUpdateNotifier.value = null;
          debugPrint('[CreateOrderScreen] orderStatusUpdateNotifier.value null yapıldı. (after refresh)');
        }
      });
    }
  }

  void _checkAndHandlePendingNotifications() {
    debugPrint('[CreateOrderScreen] _checkAndHandlePendingNotifications çağrıldı.');
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('[CreateOrderScreen] _checkAndHandlePendingNotifications postFrameCallback');
        if (mounted) {
          _handleShowNotificationDialogIfNeeded();
          if (shouldRefreshTablesNotifier.value) {
            _handleRefreshFromNotifier();
          }
        }
      });
    }
  }

  Future<void> _openWaitingCustomersModal() async {
    debugPrint('[CreateOrderScreen] _openWaitingCustomersModal çağrıldı.');
    _controller!.openWaitingCustomersModal(
      WaitingCustomersModal(
        token: widget.token,
        onCustomerListUpdated: _controller!.refreshWaitingCount,
      ),
    );
  }
  
  Future<void> _navigateToEditScreen(dynamic order) async {
    debugPrint('[CreateOrderScreen] _navigateToEditScreen çağrıldı.');
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditOrderScreen(
          token: widget.token,
          order: order,
          allMenuItems: _controller!.menuItems,
          businessId: widget.businessId,
        ),
      ),
    );
    debugPrint('[CreateOrderScreen] EditOrderScreen\'den dönen result: $result');
    if (result == true && mounted) {
      debugPrint('[CreateOrderScreen] Edit sonucu başarılı, tablo refresh.');
      _controller!.refreshData();
    }
  }

  Future<void> _handleTableTap(dynamic table, bool isOccupied, dynamic pendingOrder) async {
    debugPrint('[CreateOrderScreen] _handleTableTap BAŞLANGIÇ. isOccupied: $isOccupied, table: $table, pendingOrder: $pendingOrder');
    if (isOccupied && pendingOrder != null) {
      final String status = pendingOrder['status'] ?? '';
      debugPrint('[CreateOrderScreen] Pending order var, status: $status');

      if (status == 'pending_sync') {
        await _navigateToEditScreen(pendingOrder);
        debugPrint('[CreateOrderScreen] pending_sync sonrası navigateToEditScreen tamam.');
      } else {
        final result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (modalContext) => TableOrderDetailsModal(
            table: table,
            pendingOrder: pendingOrder,
            token: widget.token,
            allMenuItems: _controller!.menuItems,
            onOrderUpdated: _controller!.refreshData,
            onApprove: (order) => _controller!.handleApproveGuestOrder(order['id']),
            onReject: (order) => _controller!.handleRejectGuestOrder(order['id']),
            onCancel: (order) => _showCancelDialog(order),
            onTransfer: (order) => _showTransferDialog(order),
            onAddItem: (order) => _navigateToEditScreen(order),
          ),
        );
        debugPrint('[CreateOrderScreen] showModalBottomSheet sonucu: $result');
        if (result == 'edit_order' || result == 'add_item') {
          await _navigateToEditScreen(pendingOrder);
          debugPrint('[CreateOrderScreen] edit/add sonrası navigateToEditScreen tamam.');
        } else if (result == 'transfer_order') {
          _showTransferDialog(pendingOrder);
        } else if (result == 'cancel_order') {
          _showCancelDialog(pendingOrder);
        }
      }
    } else {
      debugPrint('[CreateOrderScreen] NewOrderScreen açılıyor...');
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewOrderScreen(
            token: widget.token,
            table: table,
            businessId: widget.businessId,
          ),
        ),
      );
      // Sipariş sonrası ana ekrana dönmek için kodu buraya koyma!
      // NewOrderScreen'de navigation zinciri kesin şekilde yönetilecek!
    }
    debugPrint('[CreateOrderScreen] _handleTableTap SONU.');
  }

  void _showTransferDialog(dynamic pendingOrder) {
    debugPrint('[CreateOrderScreen] _showTransferDialog çağrıldı.');
    final l10n = AppLocalizations.of(context)!;
    if (pendingOrder['status'] == 'pending_approval' || pendingOrder['status'] == 'rejected') {
        debugPrint('[CreateOrderScreen] Transfer yapılamaz, status: ${pendingOrder['status']}');
        _controller!.showSnackBarCallback(l10n.createOrderErrorCannotTransfer(pendingOrder['status_display']), isError: true);
        return;
    }
    CreateOrderDialogs.showTransferDialog(
      context: context,
      pendingOrder: pendingOrder,
      tables: _controller!.tables,
      pendingOrders: _controller!.pendingOrders,
      onConfirm: _controller!.handleTransferOrder,
    );
  }

  void _showCancelDialog(dynamic pendingOrder) {
    debugPrint('[CreateOrderScreen] _showCancelDialog çağrıldı.');
    final l10n = AppLocalizations.of(context)!;
    if (pendingOrder['status'] == 'rejected' || pendingOrder['status'] == 'cancelled' || pendingOrder['status'] == 'completed') {
        debugPrint('[CreateOrderScreen] Cancel yapılamaz, status: ${pendingOrder['status']}');
        _controller!.showSnackBarCallback(l10n.createOrderErrorAlreadyProcessed, isError: true);
        return;
    }
    CreateOrderDialogs.showCancelDialog(
      context: context,
      pendingOrder: pendingOrder,
      onConfirm: _controller!.handleCancelOrder,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[CreateOrderScreen] build');
    final l10n = AppLocalizations.of(context)!;
    if (_controller == null) {
      debugPrint('[CreateOrderScreen] controller null, loading...');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home, color: Colors.white),
                      onPressed: () {
                        debugPrint('[CreateOrderScreen] Ana ekran home butonu tıklandı.');
                        widget.onGoHome();
                      },
                      tooltip: l10n.createOrderTooltipGoHome,
                    ),
                    WaitingCustomerButton(
                      count: _controller!.waitingCount,
                      onPressed: _openWaitingCustomersModal,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !_isInitialLoadComplete && _controller!.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _controller!.errorMessage.isNotEmpty && _controller!.tables.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, color: Colors.orangeAccent.shade100, size: 48),
                                  const SizedBox(height: 16),
                                  Text(
                                    _controller!.errorMessage,
                                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: Text(l10n.createOrderButtonRetry),
                                    onPressed: _controller!.refreshData,
                                  )
                                ],
                              ),
                            ),
                          )
                        : TablesGridView(
                            tables: _controller!.tables,
                            pendingOrders: _controller!.pendingOrders,
                            menuItems: _controller!.menuItems,
                            token: widget.token,
                            businessId: widget.businessId,
                            onRefresh: _controller!.refreshData,
                            onTapTable: _handleTableTap,
                            onTransferTable: _showTransferDialog,
                            onCancelOrder: _showCancelDialog,
                            onOrderUpdated: _controller!.refreshData,
                            onApprove: (order) => _controller!.handleApproveGuestOrder(order['id']),
                            onReject: (order) => _controller!.handleRejectGuestOrder(order['id']),
                            onAddItem: (order) => _navigateToEditScreen(order),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
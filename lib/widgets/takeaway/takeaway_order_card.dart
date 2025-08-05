// lib/widgets/takeaway/takeaway_order_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:makarna_app/screens/takeaway_edit_order_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/order.dart' as AppOrder;
import '../../models/order_item.dart';
import '../../services/order_service.dart';
import '../../services/pager_service.dart';
import '../../utils/localization_helper.dart';

class TakeawayOrderCardWidget extends StatefulWidget {
  final AppOrder.Order order;
  final String token;
  final VoidCallback onCancel;
  final VoidCallback onOrderUpdated;
  final VoidCallback onAssignPager;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  // --- GÜNCELLEME: onTap callback'i eklendi ---
  final VoidCallback onTap;

  const TakeawayOrderCardWidget({
    Key? key,
    required this.order,
    required this.token,
    required this.onCancel,
    required this.onOrderUpdated,
    required this.onAssignPager,
    required this.onApprove,
    required this.onReject,
    required this.onTap, // Constructor'a eklendi
  }) : super(key: key);

  @override
  _TakeawayOrderCardWidgetState createState() => _TakeawayOrderCardWidgetState();
}

class _TakeawayOrderCardWidgetState extends State<TakeawayOrderCardWidget> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isProcessingAction = false;
  String? _assignedPagerDeviceId;
  String? _assignedPagerName;

  // Durum ve KDS durum sabitleri
  static const String STATUS_PENDING_APPROVAL = 'pending_approval';
  static const String STATUS_PENDING_SYNC = 'pending_sync';
  static const String STATUS_APPROVED = 'approved';
  static const String STATUS_PREPARING = 'preparing';
  static const String STATUS_READY_FOR_PICKUP = 'ready_for_pickup';
  static const String STATUS_READY_FOR_DELIVERY = 'ready_for_delivery';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';
  static const String STATUS_REJECTED = 'rejected';

  static const String KDS_ITEM_STATUS_PENDING = 'pending_kds';
  static const String KDS_ITEM_STATUS_PREPARING = 'preparing_kds';
  static const String KDS_ITEM_STATUS_READY = 'ready_kds';
  static const String KDS_ITEM_STATUS_PICKED_UP = 'picked_up_kds';

  @override
  void initState() {
    super.initState();
    _updateOrderState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TakeawayOrderCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order.id != oldWidget.order.id || widget.order.status != oldWidget.order.status) {
      _timer?.cancel();
      _updateOrderState();
      _startTimerIfNeeded();
    }
  }

  void _updateOrderState() {
    if (!mounted) return;
    setState(() {
      final pagerInfo = widget.order.payment as Map<String, dynamic>?;
      if (pagerInfo != null) {
        _assignedPagerDeviceId = pagerInfo['device_id'] as String?;
        _assignedPagerName = pagerInfo['name'] as String?;
      } else {
        _assignedPagerDeviceId = null;
        _assignedPagerName = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    final bool isOrderFinalized = [
      AppOrder.OrderStatus.completed,
      AppOrder.OrderStatus.cancelled,
      AppOrder.OrderStatus.rejected,
    ].contains(widget.order.orderStatusEnum) || widget.order.isPaid;

    if (!isOrderFinalized && widget.order.createdAt != null) {
      try {
        DateTime createdAt = DateTime.parse(widget.order.createdAt!);
        _timer?.cancel();
        _updateElapsedSeconds(createdAt);
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          _updateElapsedSeconds(createdAt);
        });
      } catch (e) {
        if (mounted) setState(() => _elapsedSeconds = 0);
      }
    } else {
      _timer?.cancel();
    }
  }

  void _updateElapsedSeconds(DateTime startTime) {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() => _elapsedSeconds = now.difference(startTime).inSeconds);
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  Future<void> _handleItemPickup(OrderItem item, AppLocalizations l10n) async {
    if (!mounted || _isProcessingAction || item.id == null) return;
    setState(() => _isProcessingAction = true);
    try {
      final response = await OrderService.markItemPickedUpByWaiter(token: widget.token, orderItemId: item.id!);
      if (mounted) {
        if (response.statusCode == 200) {
          widget.onOrderUpdated();
        } else {
          _showErrorSnackbar(l10n.takeawayCardErrorItemPickup(response.statusCode.toString()));
        }
      }
    } catch (e) {
      _showErrorSnackbar(l10n.takeawayCardErrorItemPickupGeneric(e.toString()));
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleDeliverOrderItem(OrderItem item, AppLocalizations l10n) async {
    if (!mounted || _isProcessingAction || widget.order.id == null || item.id == null) return;
    setState(() => _isProcessingAction = true);
    try {
      final response = await OrderService.markOrderItemDelivered(
          token: widget.token, orderId: widget.order.id!, orderItemId: item.id!);
      if (mounted) {
        if (response.statusCode == 200) {
          widget.onOrderUpdated();
        } else {
          _showErrorSnackbar(l10n.errorDeliveringItem(response.statusCode.toString()));
        }
      }
    } catch (e) {
      _showErrorSnackbar(l10n.errorDeliveringItemGeneral(e.toString()));
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Widget _buildStatusHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            "#${widget.order.id ?? widget.order.uuid?.substring(0, 5)} - ${widget.order.customerName ?? l10n.guestCustomerName}",
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_elapsedSeconds),
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildItemRow(OrderItem item, AppLocalizations l10n) {
    final bool isDelivered = item.waiterPickedUpAt != null;
    final String kdsStatus = item.kdsStatus ?? KDS_ITEM_STATUS_PENDING;
    Widget actionWidget;

    if (isDelivered) {
      actionWidget = Tooltip(message: l10n.takeawayCardTooltipDelivered, child: Icon(Icons.check_circle, size: 28, color: Colors.green.shade600));
    } else if (kdsStatus == KDS_ITEM_STATUS_READY) {
      actionWidget = IconButton(icon: const Icon(Icons.pan_tool_alt_outlined, size: 28), color: Colors.purple.shade600, padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: l10n.takeawayCardTooltipMarkAsPickedUp, onPressed: _isProcessingAction ? null : () => _handleItemPickup(item, l10n));
    } else if (kdsStatus == KDS_ITEM_STATUS_PICKED_UP) {
      actionWidget = IconButton(icon: const Icon(Icons.room_service_outlined, size: 28), color: Colors.blue.shade600, padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: l10n.takeawayCardTooltipDeliverToCustomer, onPressed: _isProcessingAction ? null : () => _handleDeliverOrderItem(item, l10n));
    } else if (kdsStatus == KDS_ITEM_STATUS_PREPARING) {
      actionWidget = Tooltip(message: l10n.kdsStatusPreparing, child: Icon(Icons.whatshot, size: 24, color: Colors.orange.shade800));
    } else {
      actionWidget = Tooltip(message: l10n.kdsStatusWaitingForApproval, child: Icon(Icons.hourglass_empty, size: 22, color: Colors.grey.shade600));
    }

    final String variantNameDisplay = (item.variant?.name != null && item.variant!.name.isNotEmpty) ? ' (${item.variant!.name})' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Opacity(
              opacity: isDelivered ? 0.6 : 1.0,
              child: Text(
                "${item.quantity}x ${item.menuItem.name}$variantNameDisplay",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  decoration: isDelivered ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          actionWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isPaid = widget.order.isPaid;
    final bool isCancelled = widget.order.orderStatusEnum == AppOrder.OrderStatus.cancelled;
    final bool isCompleted = widget.order.orderStatusEnum == AppOrder.OrderStatus.completed;
    final bool isRejected = widget.order.orderStatusEnum == AppOrder.OrderStatus.rejected;
    final bool isPendingApproval = widget.order.orderStatusEnum == AppOrder.OrderStatus.pendingApproval;
    final bool isPendingSync = widget.order.id == -1 && (widget.order.status == 'pending_sync' || widget.order.status == null);

    Color cardColor;
    switch (widget.order.status) {
      case STATUS_PENDING_SYNC: cardColor = Colors.grey.shade400; break;
      case STATUS_PENDING_APPROVAL: cardColor = Colors.purple.shade200; break;
      case STATUS_READY_FOR_PICKUP:
      case STATUS_READY_FOR_DELIVERY: cardColor = Colors.teal.shade300; break;
      case STATUS_PREPARING: cardColor = Colors.orange.shade300; break;
      case STATUS_APPROVED: cardColor = Colors.blue.shade300; break;
      default: cardColor = Colors.blueGrey.shade300;
    }

    return GestureDetector(
      // --- GÜNCELLEME: onTap artık doğrudan widget'tan gelen callback'i çağırıyor ---
      onTap: (isPaid || isCancelled || isCompleted || isRejected) ? null : widget.onTap,
      child: Card(
        color: cardColor,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardColor.withBlue(180).withGreen(150), width: 2)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(l10n),
                  Text(
                    getLocalizedOrderStatus(context, widget.order.status),
                    style: TextStyle(color: Colors.black.withOpacity(0.7), fontWeight: FontWeight.w500),
                  ),
                  const Divider(height: 12, thickness: 0.5, color: Colors.black38),
                  Expanded(
                    child: widget.order.orderItems.isEmpty
                        ? Center(child: Text(l10n.errorNoOrderItems))
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: widget.order.orderItems.length,
                            itemBuilder: (context, index) => _buildItemRow(widget.order.orderItems[index], l10n),
                          ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: isPendingSync
                    ? Center(child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.sync, size: 16, color: Colors.black54), const SizedBox(width: 8), Text(l10n.takeawayCardStatusSyncPending, style: const TextStyle(color: Colors.black54))]))
                    : isPendingApproval
                        // ♻️ DEĞİŞİKLİK BAŞLANGICI: Butonlar sadece ikon gösterecek ve Tooltip içerecek şekilde güncellendi.
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message: l10n.buttonApprove,
                                  child: ElevatedButton(
                                    onPressed: widget.onApprove,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero, // İç boşluğu sıfırla
                                    ),
                                    child: const Icon(Icons.check_circle, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Tooltip(
                                  message: l10n.buttonReject,
                                  child: ElevatedButton(
                                    onPressed: widget.onReject,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade700,
                                      foregroundColor: Colors.white,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero, // İç boşluğu sıfırla
                                    ),
                                    child: const Icon(Icons.cancel, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          )
                        // ♻️ DEĞİŞİKLİK SONU
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Spacer(),
                              IconButton(icon: const Icon(Icons.cancel_outlined), iconSize: 22, color: Colors.red.shade800, tooltip: l10n.tooltipCancelOrder, onPressed: widget.onCancel),
                              IconButton(icon: Icon(Icons.phonelink_ring_outlined, color: (_assignedPagerDeviceId != null && _assignedPagerDeviceId!.isNotEmpty) ? Colors.blue.shade800 : Colors.black54, size: 22), tooltip: _assignedPagerDeviceId != null && _assignedPagerDeviceId!.isNotEmpty ? l10n.takeawayCardTooltipPagerInfo(_assignedPagerName ?? _assignedPagerDeviceId!) : l10n.takeawayCardTooltipAssignPager, onPressed: widget.onAssignPager),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
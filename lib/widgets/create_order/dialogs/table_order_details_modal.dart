// lib/widgets/create_order/dialogs/table_order_details_modal.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../models/menu_item.dart';
import '../../../services/order_service.dart';
import '../../../utils/notifiers.dart';
import '../../table_cell_widget.dart';

class TableOrderDetailsModal extends StatefulWidget {
  final dynamic table;
  final dynamic pendingOrder;
  final String token;
  final List<MenuItem> allMenuItems;
  final VoidCallback onOrderUpdated;
  final Function(dynamic order) onApprove;
  final Function(dynamic order) onReject;
  final Function(dynamic order) onCancel;
  final Function(dynamic order) onTransfer;
  final Function(dynamic order) onAddItem;

  const TableOrderDetailsModal({
    Key? key,
    required this.table,
    required this.pendingOrder,
    required this.token,
    required this.allMenuItems,
    required this.onOrderUpdated,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onTransfer,
    required this.onAddItem,
  }) : super(key: key);

  @override
  _TableOrderDetailsModalState createState() => _TableOrderDetailsModalState();
}

class _TableOrderDetailsModalState extends State<TableOrderDetailsModal> {
  late Map<String, dynamic> _currentOrder;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = Map<String, dynamic>.from(widget.pendingOrder);
    orderStatusUpdateNotifier.addListener(_handleSilentOrderUpdates);
  }

  @override
  void dispose() {
    orderStatusUpdateNotifier.removeListener(_handleSilentOrderUpdates);
    super.dispose();
  }

  Future<void> _refreshOrderDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);
    try {
      final updatedOrder = await OrderService.fetchOrderDetails(
        token: widget.token,
        orderId: _currentOrder['id'],
      );
      if (mounted && updatedOrder != null) {
        setState(() {
          _currentOrder = updatedOrder;
        });
      }
    } catch (e) {
      debugPrint("Modal içinden sipariş detayı çekilirken hata: $e");
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tableOrderDetailsModalUpdateError), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
        widget.onOrderUpdated();
      }
    }
  }

  void _handleSilentOrderUpdates() {
    final data = orderStatusUpdateNotifier.value;
    if (data != null && mounted) {
      final updatedOrderId = data['order_id'] as int?;
      if (updatedOrderId != null && updatedOrderId == _currentOrder['id']) {
        debugPrint("[TableOrderDetailsModal] İlgili sipariş (#$updatedOrderId) için anlık güncelleme alındı. Veri yenileniyor.");
        _refreshOrderDetails();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueGrey.shade800,
            Colors.blueGrey.shade900,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10.0),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          Expanded(
            child: _isLoadingDetails
                ? const Center(child: CircularProgressIndicator())
                : TableCellWidget(
                    table: widget.table,
                    isOccupied: true,
                    pendingOrder: _currentOrder,
                    token: widget.token,
                    allMenuItems: widget.allMenuItems,
                    onOrderUpdated: _refreshOrderDetails,  
                    onTap: () {
                      Navigator.of(context).pop('edit_order');
                    },
                    onTransfer: () {
                      Navigator.of(context).pop('transfer_order');
                    },
                    onCancel: () {
                      Navigator.of(context).pop('cancel_order');
                    },
                    onApprove: () async {
                      await widget.onApprove(_currentOrder);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    onReject: () async {
                      await widget.onReject(_currentOrder);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    onAddItem: () {
                      Navigator.of(context).pop('add_item');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
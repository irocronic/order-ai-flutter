// lib/screens/purchase_order_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/purchase_order.dart';
import '../services/procurement_service.dart';
import '../services/user_session.dart';
import '../utils/currency_formatter.dart';
import 'create_purchase_order_screen.dart';

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({Key? key}) : super(key: key);

  @override
  _PurchaseOrderListScreenState createState() =>
      _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  late Future<List<PurchaseOrder>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = ProcurementService.fetchPurchaseOrders(UserSession.token);
    });
  }

  // ==================== YENİ METOT ====================
  Future<void> _cancelOrder(PurchaseOrder order) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.purchaseOrderCancelDialogTitle),
        content: Text(l10n.purchaseOrderCancelDialogContent(order.id.toString())),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.dialogButtonNo),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.dialogButtonYesCancel),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await ProcurementService.cancelPurchaseOrder(UserSession.token, order.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseOrderSuccessCancel(order.id.toString())),
            backgroundColor: Colors.green,
          ),
        );
        _refreshOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorGeneral(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchaseOrderListTitle,
            style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<PurchaseOrder>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text(l10n.errorGeneral(snapshot.error.toString()),
                      style: const TextStyle(color: Colors.orangeAccent)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                  child: Text(l10n.purchaseOrderNoItems,
                      style: const TextStyle(color: Colors.white70)));
            }

            final orders = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                
                IconData statusIcon;
                Color statusColor;
                switch (order.status) {
                    case 'completed':
                        statusIcon = Icons.check_circle;
                        statusColor = Colors.green;
                        break;
                    case 'cancelled':
                        statusIcon = Icons.cancel;
                        statusColor = Colors.red;
                        break;
                    default: // pending
                        statusIcon = Icons.pending;
                        statusColor = Colors.orange;
                }

                return Card(
                  color: Colors.white.withOpacity(0.9),
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ListTile(
                    leading: Icon(statusIcon, color: statusColor),
                    title: Text(
                        '${l10n.purchaseOrderLabel}: #${order.id} - ${order.supplierName}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${l10n.purchaseOrderStatusLabel}: ${order.status}\n${l10n.purchaseOrderDateLabel}: ${DateFormat('dd.MM.yyyy').format(order.createdAt)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(CurrencyFormatter.format(order.totalCost),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        // ==================== GÜNCELLENEN BÖLÜM ====================
                        if (order.status == 'pending')
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'cancel') {
                                _cancelOrder(order);
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text(l10n.dialogButtonCancelOrder, style: const TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        // ==========================================================
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CreatePurchaseOrderScreen()));
          if (result == true) {
            _refreshOrders();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.purchaseOrderAddButton),
      ),
    );
  }
}
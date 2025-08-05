// lib/widgets/create_order/tables_grid_view.dart

import 'package:flutter/material.dart';
import '../../models/menu_item.dart';
import '../table_cell_widget.dart';

class TablesGridView extends StatelessWidget {
  final List<dynamic> tables;
  final List<dynamic> pendingOrders;
  final List<MenuItem> menuItems;
  final String token;
  final int businessId;
  final Future<void> Function() onRefresh;
  final Function(dynamic table, bool isOccupied, dynamic pendingOrder) onTapTable;
  final Function(dynamic pendingOrder) onTransferTable;
  final Function(dynamic pendingOrder) onCancelOrder;
  final VoidCallback onOrderUpdated;
  final Function(dynamic order) onApprove;
  final Function(dynamic order) onReject;
  final Function(dynamic order) onAddItem;

  const TablesGridView({
    Key? key,
    required this.tables,
    required this.pendingOrders,
    required this.menuItems,
    required this.token,
    required this.businessId,
    required this.onRefresh,
    required this.onTapTable,
    required this.onTransferTable,
    required this.onCancelOrder,
    required this.onOrderUpdated,
    required this.onApprove,
    required this.onReject,
    required this.onAddItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth > 1200) {
      crossAxisCount = 5;
    } else if (screenWidth > 900) {
      crossAxisCount = 4;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: Colors.white,
      backgroundColor: Colors.blue.shade700,
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: tables.length,
        itemBuilder: (context, index) {
          var table = tables[index];
          var tableOrders = pendingOrders
              .where((order) => order['table'] == table['id'])
              .toList();
          bool isOccupied = tableOrders.isNotEmpty;
          dynamic pendingOrder = isOccupied ? tableOrders.first : null;

          return TableCellWidget(
            key: ValueKey(table['id']),
            table: table,
            isOccupied: isOccupied,
            pendingOrder: pendingOrder,
            token: token,
            allMenuItems: menuItems,
            onTap: () => onTapTable(table, isOccupied, pendingOrder),
            onTransfer: () {
              if (pendingOrder != null) {
                onTransferTable(pendingOrder);
              }
            },
            onCancel: () {
              if (pendingOrder != null) {
                onCancelOrder(pendingOrder);
              }
            },
            onOrderUpdated: onOrderUpdated,
            onApprove: () {
              if (pendingOrder != null) {
                onApprove(pendingOrder);
              }
            },
            onReject: () {
              if (pendingOrder != null) {
                onReject(pendingOrder);
              }
            },
            onAddItem: () {
              if (pendingOrder != null) {
                onAddItem(pendingOrder);
              }
            },
          );
        },
      ),
    );
  }
}
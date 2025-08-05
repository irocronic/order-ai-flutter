// lib/widgets/create_order/dialogs/create_order_dialogs.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// CreateOrderScreen için kullanılan dialogları gösteren yardımcı sınıf.
class CreateOrderDialogs {
  /// Masa transferi dialoğunu gösterir.
  static void showTransferDialog({
    required BuildContext context,
    required dynamic pendingOrder,
    required List<dynamic> tables, // Tüm masalar
    required List<dynamic> pendingOrders, // Aktif siparişler (boş masaları bulmak için)
    required Future<void> Function(int orderId, int newTableId) onConfirm,
  }) {
    final l10n = AppLocalizations.of(context)!;
    List<dynamic> emptyTables = tables.where((table) {
      return !pendingOrders.any((order) => order['table'] == table['id']);
    }).toList();

    if (emptyTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dialogTransferErrorNoEmptyTables)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        dynamic selectedNewTable = emptyTables.first;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF283593).withOpacity(0.9),
                      const Color(0xFF455A64).withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 2)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.dialogTransferTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.dialogTransferContent(pendingOrder['table'].toString()),
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<dynamic>(
                      value: selectedNewTable,
                      decoration: InputDecoration(
                        labelText: l10n.dialogTransferDropdownLabel,
                        labelStyle: const TextStyle(color: Colors.black87),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white70,
                      ),
                      dropdownColor: Colors.blue.shade800,
                      style: const TextStyle(color: Colors.black87),
                      items: emptyTables.map((table) {
                        return DropdownMenuItem(
                          value: table,
                          child: Text(l10n.manageTablesCardTitle(table['table_number'].toString()), style: const TextStyle(color: Colors.black87)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedNewTable = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(l10n.dialogButtonCancel, style: const TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            shadowColor: Colors.black.withOpacity(0.25),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            onConfirm(pendingOrder['id'], selectedNewTable['id']);
                          },
                          child: Text(l10n.dialogTransferButtonTransfer),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Sipariş iptali dialoğunu gösterir.
  static Future<void> showCancelDialog({
    required BuildContext context,
    required dynamic pendingOrder,
    required Future<void> Function(int orderId) onConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF283593).withOpacity(0.9),
                  const Color(0xFF455A64).withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.dialogCancelOrderTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                const SizedBox(height: 12),
                Text(
                  l10n.dialogCancelOrderContent,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(l10n.dialogButtonNo, style: const TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.black.withOpacity(0.25),
                        elevation: 4,
                      ),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(l10n.dialogButtonYesCancel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirm == true) {
      await onConfirm(pendingOrder['id']);
    }
  }
}
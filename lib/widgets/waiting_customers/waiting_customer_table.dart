// lib/widgets/waiting_customers/waiting_customer_table.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // YENİ: Yerelleştirme importu

/// Bekleyen müşteri listesini DataTable içinde gösteren widget.
class WaitingCustomerTable extends StatelessWidget {
  final List<dynamic> customers;
  final Function(dynamic customer) onEdit;
  final Function(dynamic customer) onDelete;

  const WaitingCustomerTable({
    Key? key,
    required this.customers,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  // GÜNCELLEME: Metot artık AppLocalizations nesnesini parametre olarak alıyor.
  String _calculateWaitingTime(String? createdAtStr, AppLocalizations l10n) {
    if (createdAtStr == null) return l10n.dataNotAvailable; // Yerelleştirilmiş fallback
    try {
      DateTime createdAt = DateTime.parse(createdAtStr);
      int waitingMinutes = DateTime.now().difference(createdAt).inMinutes;
      if (waitingMinutes < 0) waitingMinutes = 0;
      return l10n.waitingCustomerTableWaitingTime(waitingMinutes.toString()); // Yerelleştirilmiş metin
    } catch (e) {
      print("Tarih parse hatası (Table): $createdAtStr - $e");
      return l10n.dataNotAvailable; // Yerelleştirilmiş fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    // YENİ: l10n nesnesi build metodu içinde alınıyor.
    final l10n = AppLocalizations.of(context)!;
    
    if (customers.isEmpty) {
      // GÜNCELLEME: Yerelleştirilmiş metin
      return Center(
          child: Text(l10n.waitingCustomerTableNoCustomers,
              style: const TextStyle(
                  color: Colors.white70, fontStyle: FontStyle.italic)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 12.0,
              horizontalMargin: 8.0,
              dataRowColor:
                  MaterialStateProperty.all(Colors.white.withOpacity(0.8)),
              headingRowColor:
                  MaterialStateProperty.all(Colors.blueGrey.withOpacity(0.5)),
              headingTextStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              dataTextStyle: const TextStyle(color: Colors.black87),
              columns: [
                // GÜNCELLEME: Tüm başlıklar yerelleştirildi.
                DataColumn(label: Text(l10n.waitingCustomerTableColOrder)),
                DataColumn(label: Text(l10n.waitingCustomerTableColName)),
                DataColumn(label: Text(l10n.waitingCustomerTableColPhone)),
                DataColumn(label: Text(l10n.waitingCustomerTableColWaitingTime)),
                DataColumn(label: Text(l10n.waitingCustomerTableColActions)),
              ],
              rows: List<DataRow>.generate(
                customers.length,
                (index) {
                  final customer = customers[index];
                  return DataRow(
                    cells: [
                      DataCell(Text("${index + 1}")),
                      DataCell(Text(customer['name'] ?? "")),
                      DataCell(Text(customer['phone'] ?? "")),
                      // GÜNCELLEME: _calculateWaitingTime metoduna l10n nesnesi gönderiliyor.
                      DataCell(
                          Text(_calculateWaitingTime(customer['created_at'], l10n))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.edit,
                                color: Colors.blueAccent, size: 20),
                            // GÜNCELLEME: Yerelleştirilmiş tooltip
                            tooltip: l10n.tooltipEdit,
                            onPressed: () => onEdit(customer),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent, size: 20),
                            // GÜNCELLEME: Yerelleştirilmiş tooltip
                            tooltip: l10n.tooltipDelete,
                            onPressed: () => onDelete(customer),
                          ),
                        ],
                      )),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
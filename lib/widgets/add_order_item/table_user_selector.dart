// lib/widgets/add_order_item/table_user_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../controllers/add_order_item_dialog_controller.dart';

class TableUserSelector extends StatelessWidget {
  final AddOrderItemDialogController controller;

  const TableUserSelector({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (controller.tableUsers.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<String>(
      value: controller.selectedTableUser,
      decoration: InputDecoration(
        labelText: l10n.variantSelectionDialogTableOwnerLabel,
        labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.white70,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dropdownColor: Colors.blue.shade800,
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      items: controller.tableUsers.map<DropdownMenuItem<String>>((user) {
        return DropdownMenuItem<String>(
          value: user,
          child: Text(user, style: const TextStyle(color: Colors.black87)),
        );
      }).toList(),
      onChanged: (value) => controller.selectTableUser(value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return l10n.variantSelectionDialogTableOwnerValidator;
        }
        return null;
      },
    );
  }
}
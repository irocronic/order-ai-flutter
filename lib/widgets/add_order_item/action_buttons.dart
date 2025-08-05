// lib/widgets/add_order_item/action_buttons.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../controllers/add_order_item_dialog_controller.dart';
import '../../models/menu_item.dart';
import '../../models/menu_item_variant.dart';

class ActionButtons extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final AddOrderItemDialogController controller;
  final Function(MenuItem item, MenuItemVariant? variant, List<MenuItemVariant> extras, String? tableUser) onItemsAdded;

  const ActionButtons({
    Key? key,
    required this.formKey,
    required this.controller,
    required this.onItemsAdded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.dialogButtonCancel),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.8),
            foregroundColor: Colors.black,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final selection = controller.getFinalSelection();
              if (selection != null) {
                onItemsAdded(
                  selection['item'],
                  selection['variant'],
                  selection['extras'],
                  selection['tableUser'],
                );
                Navigator.pop(context);
              } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.addOrderItemDialogSelectionError), backgroundColor: Colors.orangeAccent),
                  );
              }
            }
          },
          child: Text(l10n.pagerButtonAdd, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
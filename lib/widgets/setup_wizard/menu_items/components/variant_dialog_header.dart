// lib/widgets/setup_wizard/menu_items/components/variant_dialog_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class VariantDialogHeader extends StatelessWidget {
  final String menuItemName;
  final VoidCallback onClose;

  const VariantDialogHeader({
    Key? key,
    required this.menuItemName,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Icon(Icons.tune, color: Colors.blue.shade700, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.menuItemVariantsDialogTitle(menuItemName),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
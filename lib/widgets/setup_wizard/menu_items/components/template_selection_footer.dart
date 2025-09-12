// lib/widgets/setup_wizard/menu_items/components/template_selection_footer.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/variant_template_config.dart';

class TemplateSelectionFooter extends StatelessWidget {
  final bool isButtonEnabled;
  final List<int> selectedTemplateIds;
  final Map<int, VariantTemplateConfig> templateVariantConfigs;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const TemplateSelectionFooter({
    Key? key,
    required this.isButtonEnabled,
    required this.selectedTemplateIds,
    required this.templateVariantConfigs,
    required this.onCancel,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(4.0),
          bottomRight: Radius.circular(4.0),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            child: Text(
              l10n.dialogButtonCancel,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: isButtonEnabled ? onConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isButtonEnabled ? Colors.blue : Colors.grey,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Builder(
                builder: (context) {
                  int totalVariants = 0;
                  for (int templateId in selectedTemplateIds) {
                    final config = templateVariantConfigs[templateId];
                    totalVariants += config?.variants.length ?? 0;
                  }
                  final variantText = totalVariants > 0 ? ' + $totalVariants varyant' : '';
                  return Text(
                    '${selectedTemplateIds.length} ürün$variantText - Ekle',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
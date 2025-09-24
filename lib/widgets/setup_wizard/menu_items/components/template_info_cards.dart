// lib/widgets/setup_wizard/menu_items/components/template_info_cards.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../models/variant_template_config.dart';

class TemplateInfoCards extends StatelessWidget {
  final int currentMenuItemCount;
  final List<int> selectedTemplateIds;
  final Map<int, VariantTemplateConfig> templateVariantConfigs;

  const TemplateInfoCards({
    Key? key,
    required this.currentMenuItemCount,
    required this.selectedTemplateIds,
    required this.templateVariantConfigs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Limit bilgisi
        Container(
          padding: const EdgeInsets.all(8.0),
          margin: const EdgeInsets.only(bottom: 12.0),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.itemSelectionInfo(
                    currentMenuItemCount.toString(),
                    selectedTemplateIds.length.toString(),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        
        // Varyant durumu özeti
        if (selectedTemplateIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8.0),
            margin: const EdgeInsets.only(bottom: 12.0),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      int totalVariants = 0;
                      int variantsWithPhoto = 0;
                      for (int templateId in selectedTemplateIds) {
                        final config = templateVariantConfigs[templateId];
                        if (config != null) {
                          totalVariants += config.variants.length;
                          if (config.hasVariantImageEnabled && config.hasVariantImage) {
                            variantsWithPhoto++;
                          }
                        }
                      }
                      final photoText = variantsWithPhoto > 0 ? ' (📸$variantsWithPhoto)' : '';
                      return Text(
                        l10n.totalVariantsInfo(totalVariants.toString()) + photoText,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
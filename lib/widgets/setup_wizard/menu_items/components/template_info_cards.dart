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

    return Row(
      children: [
        Icon(
          Icons.info_outline, 
          color: Colors.white.withOpacity(0.9), 
          size: 16
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l10n.itemSelectionInfo(
              currentMenuItemCount.toString(),
              selectedTemplateIds.length.toString(),
            ),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
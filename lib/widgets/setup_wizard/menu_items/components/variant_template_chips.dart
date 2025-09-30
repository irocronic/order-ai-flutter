// lib/widgets/setup_wizard/menu_items/components/variant_template_chips.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../models/menu_item_variant.dart';

class VariantTemplateChips extends StatelessWidget {
  final List<dynamic> variantTemplates;
  final bool isLoadingTemplates;
  final bool hasTemplateLoadError;
  final String templateErrorMessage;
  final List<MenuItemVariant> variants;
  final Function(Map<String, dynamic>) onSelectTemplate;

  const VariantTemplateChips({
    Key? key,
    required this.variantTemplates,
    required this.isLoadingTemplates,
    required this.hasTemplateLoadError,
    required this.templateErrorMessage,
    required this.variants,
    required this.onSelectTemplate,
  }) : super(key: key);

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'restaurant_outlined': return Icons.restaurant_outlined;
      case 'restaurant': return Icons.restaurant;
      case 'dinner_dining': return Icons.dinner_dining;
      case 'local_cafe': return Icons.local_cafe;
      case 'cake': return Icons.cake;
      case 'fastfood': return Icons.fastfood;
      case 'lunch_dining': return Icons.lunch_dining;
      case 'local_bar': return Icons.local_bar;
      case 'wine_bar': return Icons.wine_bar;
      case 'whatshot': return Icons.whatshot;
      case 'ac_unit': return Icons.ac_unit;
      case 'favorite': return Icons.favorite;
      case 'mood': return Icons.mood;
      case 'add_circle': return Icons.add_circle;
      case 'local_drink': return Icons.local_drink;
      case 'sports_bar': return Icons.sports_bar;
      default: return Icons.label_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (variantTemplates.isEmpty) return const SizedBox.shrink();
    
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange, size: 16),
            const SizedBox(width: 4),
            Text(
              l10n.menuItemVariantsDialogQuickAddVariant,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isLoadingTemplates) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ],
            if (hasTemplateLoadError) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: templateErrorMessage,
                child: Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: isLoadingTemplates
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      l10n.menuItemVariantsDialogLoadingTemplates,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: variantTemplates.map<Widget>((template) {
                    final templateName = template['name']?.toString() ?? 'İsimsiz';
                    final isUsed = variants.any((variant) => 
                      variant.name.toLowerCase() == templateName.toLowerCase()
                    );
                    
                    return ActionChip(
                      avatar: Icon(
                        _getIconFromName(template['icon_name']?.toString() ?? 'label_outline'),
                        size: 16,
                        color: isUsed ? Colors.grey : Colors.orange.shade700,
                      ),
                      label: Text(
                        templateName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isUsed ? Colors.grey : Colors.orange.shade700,
                        ),
                      ),
                      backgroundColor: isUsed ? Colors.grey.shade200 : Colors.white,
                      onPressed: isUsed ? null : () => onSelectTemplate(template),
                      elevation: isUsed ? 0 : 2,
                      pressElevation: 1,
                      side: BorderSide(
                        color: isUsed 
                            ? Colors.grey.shade300 
                            : Colors.orange.withOpacity(0.3),
                        width: 1,
                      ),
                    );
                  }).toList(),
                ),
        ),
        if (hasTemplateLoadError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      templateErrorMessage,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
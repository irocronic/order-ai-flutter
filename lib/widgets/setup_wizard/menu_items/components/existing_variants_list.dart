// lib/widgets/setup_wizard/menu_items/components/existing_variants_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../models/menu_item_variant.dart';
import '../../../../services/api_service.dart';

class ExistingVariantsList extends StatelessWidget {
  final bool isLoading;
  final List<MenuItemVariant> variants;
  final Function(int, String) onDeleteVariant;

  const ExistingVariantsList({
    Key? key,
    required this.isLoading,
    required this.variants,
    required this.onDeleteVariant,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (variants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.tune,
              size: 48,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.menuItemVariantsDialogNoVariantsAdded,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.menuItemVariantsDialogNoVariantsDescription,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.menuItemVariantsDialogCurrentVariants(variants.length),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...variants.map((variant) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              // Varyant görseli
              if (variant.image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    variant.image.startsWith('http')
                        ? variant.image
                        : '${ApiService.baseUrl}${variant.image}',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (c, o, s) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.label_outline,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                ),
              
              const SizedBox(width: 12),
              
              // Varyant bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₺${variant.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (variant.isExtra) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, 
                              vertical: 2
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.menuItemVariantsDialogExtraTag,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Sil butonu
              IconButton(
                onPressed: () => onDeleteVariant(variant.id, variant.name),
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red.shade600,
                ),
                tooltip: l10n.menuItemVariantsDialogDeleteVariantTooltip,
              ),
            ],
          ),
        )),
      ],
    );
  }
}
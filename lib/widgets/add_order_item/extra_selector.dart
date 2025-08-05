// lib/widgets/add_order_item/extra_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../controllers/add_order_item_dialog_controller.dart';
import '../../models/menu_item_variant.dart';
import '../../services/api_service.dart';
import '../shared/image_display.dart';
import '../../utils/currency_formatter.dart';

class ExtraSelector extends StatelessWidget {
  final AddOrderItemDialogController controller;

  const ExtraSelector({Key? key, required this.controller}) : super(key: key);

  Widget _buildVariantImageWidget(MenuItemVariant variant, {double size = 40}) {
    String? url;
    if (variant.image.isNotEmpty) {
      url = variant.image.startsWith('http')
          ? variant.image
          : '${ApiService.baseUrl}${variant.image}';
    }
    return buildImage(url, Icons.add_shopping_cart, size);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (controller.extraVariants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.variantSelectionDialogExtrasLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: controller.extraVariants.map((variant) {
            final isSelected = controller.selectedExtraVariants.contains(variant);
            return ChoiceChip(
              // --- DÜZELTME BAŞLANGICI ---
              backgroundColor: Colors.black.withOpacity(0.2), // Seçili değilkenki arka plan rengi koyulaştırıldı.
              selectedColor: Colors.white,
              label: Text(
                '${variant.name} (+${CurrencyFormatter.format(variant.price)})',
                style: TextStyle(
                  // Yazı rengi artık seçilme durumuna göre değişiyor.
                  // Seçili değilken beyaz, seçili iken koyu mavi olacak.
                  color: isSelected ? Colors.blue.shade900 : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // --- DÜZELTME SONU ---
              avatar: _buildVariantImageWidget(variant, size: 20),
              selected: isSelected,
              shape: isSelected
                  ? StadiumBorder(side: BorderSide(color: Colors.yellow.shade700, width: 2))
                  : StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.5))),
              showCheckmark: false,
              onSelected: (selected) => controller.toggleExtraVariant(variant),
            );
          }).toList(),
        ),
      ],
    );
  }
}
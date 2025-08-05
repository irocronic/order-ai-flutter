// lib/widgets/add_order_item/variant_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../controllers/add_order_item_dialog_controller.dart';
import '../../models/menu_item_variant.dart';
import '../../services/api_service.dart';
import '../shared/image_display.dart';
// --- DÜZELTME: Gerekli import eklendi ---
import '../../utils/currency_formatter.dart';

class VariantSelector extends StatelessWidget {
  final AddOrderItemDialogController controller;

  const VariantSelector({Key? key, required this.controller}) : super(key: key);

  Widget _buildVariantImageWidget(MenuItemVariant variant, {double size = 40}) {
    String? url;
    if (variant.image.isNotEmpty) {
      url = variant.image.startsWith('http')
          ? variant.image
          : '${ApiService.baseUrl}${variant.image}';
    }
    return buildImage(url, Icons.image_not_supported, size);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (controller.normalVariants.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField<MenuItemVariant>(
      value: controller.selectedNormalVariant,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.variantSelectionDialogVariantLabel,
        labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white54), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dropdownColor: Colors.blue.shade900,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      items: controller.normalVariants.map((variant) {
        return DropdownMenuItem<MenuItemVariant>(
          value: variant,
          child: Row(
            children: [
              _buildVariantImageWidget(variant, size: 24),
              const SizedBox(width: 8),
              // --- DÜZELTME BAŞLANGICI ---
              Expanded(
                child: Text(
                  '${variant.name} (${CurrencyFormatter.format(variant.price)})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white)
                ),
              ),
              // --- DÜZELTME SONU ---
            ],
          ),
        );
      }).toList(),
      onChanged: (newVariant) => controller.selectNormalVariant(newVariant),
      validator: (value) {
        if (controller.normalVariants.isNotEmpty && value == null) {
          return l10n.variantSelectionDialogVariantValidator;
        }
        return null;
      },
    );
  }
}
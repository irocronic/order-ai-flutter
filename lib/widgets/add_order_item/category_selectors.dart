// lib/widgets/add_order_item/category_selectors.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../controllers/add_order_item_dialog_controller.dart';

class CategorySelectors extends StatelessWidget {
  final AddOrderItemDialogController controller;

  const CategorySelectors({Key? key, required this.controller}) : super(key: key);

  String getCategoryName(dynamic category, AppLocalizations l10n) {
      if (category == null || (category is Map && category['id'] == null)) return l10n.categoryAll;
      if (category is Map) {
        return category['name'] ?? l10n.unknownCategory;
      }
      return category.toString();
    }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (controller.topCategories.length > 1)
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.topCategories.length,
              itemBuilder: (context, index) {
                var cat = controller.topCategories[index];
                bool isSelected = controller.selectedTopCategory?['id'] == cat['id'];
                return GestureDetector(
                  onTap: () => controller.selectTopCategory(cat),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(child: Text(getCategoryName(cat, l10n), style: TextStyle(color: isSelected ? Colors.black : Colors.black87, fontWeight: FontWeight.bold))),
                  ),
                );
              },
            ),
          ),
        if (controller.selectedTopCategory != null && controller.selectedTopCategory['id'] != null && controller.subCategories.length > 1)
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.subCategories.length,
              itemBuilder: (context, index) {
                var subCat = controller.subCategories[index];
                bool isSelected = controller.selectedSubCategory?['id'] == subCat['id'];
                return GestureDetector(
                  onTap: () => controller.selectSubCategory(subCat),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(child: Text(getCategoryName(subCat, l10n), style: TextStyle(color: isSelected ? Colors.black : Colors.black87, fontWeight: FontWeight.bold))),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
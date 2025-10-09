// lib/widgets/setup_wizard/menu_items/components/template_selection_content.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/user_session.dart';
import '../models/variant_template_config.dart';
import 'template_info_cards.dart';
import 'template_category_dropdown.dart';
import 'template_search_field.dart';
import 'template_list_widget.dart';

class TemplateSelectionContent extends StatelessWidget {
  final int currentMenuItemCount;
  final List<int> selectedTemplateIds;
  final Map<int, VariantTemplateConfig> templateVariantConfigs;
  final List<dynamic> availableCategories;
  final String? selectedCategoryName;
  final TextEditingController searchController;
  final bool isLoadingTemplates;
  final List<dynamic> allTemplates;
  final List<dynamic> filteredTemplates;
  final Map<int, bool> templateRecipeStatus;
  final Map<int, TextEditingController> templatePriceControllers;
  final int? targetCategoryId;
  final int businessId;
  final String token;
  final ScrollController? scrollController;
  final Function(String?) onCategoryChanged;
  final VoidCallback onToggleSelectAll;
  final Function(int) onToggleTemplateSelection;
  final Function(int) onToggleRecipeStatus;
  final Function(int) onOpenVariantManagement;
  final VoidCallback onShowLimitReached;
  final Function(Map<String, dynamic>) onCustomProductAdded;
  final Function(int)? onEnsureItemVisible;

  const TemplateSelectionContent({
    Key? key,
    required this.currentMenuItemCount,
    required this.selectedTemplateIds,
    required this.templateVariantConfigs,
    required this.availableCategories,
    required this.selectedCategoryName,
    required this.searchController,
    required this.isLoadingTemplates,
    required this.allTemplates,
    required this.filteredTemplates,
    required this.templateRecipeStatus,
    required this.templatePriceControllers,
    required this.targetCategoryId,
    required this.businessId,
    required this.token,
    this.scrollController,
    required this.onCategoryChanged,
    required this.onToggleSelectAll,
    required this.onToggleTemplateSelection,
    required this.onToggleRecipeStatus,
    required this.onOpenVariantManagement,
    required this.onShowLimitReached,
    required this.onCustomProductAdded,
    this.onEnsureItemVisible,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bilgi kartları - yan yana
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: TemplateInfoCards(
                    currentMenuItemCount: currentMenuItemCount,
                    selectedTemplateIds: selectedTemplateIds,
                    templateVariantConfigs: templateVariantConfigs,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune, 
                        color: Colors.white.withOpacity(0.9), 
                        size: 16
                      ),
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
                              'Toplam $totalVariants varyant$photoText',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Kategori seçimi
          TemplateCategoryDropdown(
            availableCategories: availableCategories,
            selectedCategoryName: selectedCategoryName,
            onCategoryChanged: onCategoryChanged,
          ),
          const SizedBox(height: 12),
          
          // Tümünü Seç ve Ürün Ara alanları - yan yana
          if (selectedCategoryName != null) ...[
            Row(
              children: [
                // Tümünü Seç - Solda
                Expanded(
                  child: _buildSelectAllSection(),
                ),
                const SizedBox(width: 12),
                // Ürün Ara - Sağda
                Expanded(
                  child: TemplateSearchField(
                    searchController: searchController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          // Template listesi container
          Container(
            height: keyboardHeight > 0 ? 200.0 : 350.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: TemplateListWidget(
              selectedCategoryName: selectedCategoryName,
              isLoadingTemplates: isLoadingTemplates,
              allTemplates: allTemplates,
              filteredTemplates: filteredTemplates,
              selectedTemplateIds: selectedTemplateIds,
              templateRecipeStatus: templateRecipeStatus,
              templatePriceControllers: templatePriceControllers,
              templateVariantConfigs: templateVariantConfigs,
              currentMenuItemCount: currentMenuItemCount,
              targetCategoryId: targetCategoryId,
              businessId: businessId,
              token: token,
              onToggleSelectAll: onToggleSelectAll,
              onToggleTemplateSelection: onToggleTemplateSelection,
              onToggleRecipeStatus: onToggleRecipeStatus,
              onOpenVariantManagement: onOpenVariantManagement,
              onShowLimitReached: onShowLimitReached,
              onCustomProductAdded: onCustomProductAdded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllSection() {
    final hasVisibleItems = filteredTemplates.isNotEmpty;
    final allVisibleSelected = hasVisibleItems &&
        filteredTemplates.every((template) => selectedTemplateIds.contains(template['id']));

    return Container(
      height: 56, // TextField'in varsayılan yüksekliği ile aynı
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Padding azaltıldı
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Row'un boyutunu minimize et
        children: [
          if (hasVisibleItems)
            SizedBox(
              width: 20, // Checkbox boyutu küçültüldü
              height: 20,
              child: Checkbox(
                value: allVisibleSelected,
                onChanged: (_) => onToggleSelectAll(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: Colors.white,
                checkColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.white.withOpacity(0.8)),
              ),
            )
          else
            Container(
              width: 20, // Boyut küçültüldü
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          const SizedBox(width: 6), // Boşluk azaltıldı
          Expanded(
            child: Text(
              hasVisibleItems 
                  ? (allVisibleSelected ? 'Tümünü Kaldır' : 'Tümünü Seç')
                  : 'Tümünü Seç',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13, // Font boyutu küçültüldü
                color: hasVisibleItems 
                    ? Colors.white 
                    : Colors.white.withOpacity(0.5),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (hasVisibleItems) ...[
            const SizedBox(width: 2), // Boşluk azaltıldı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Padding azaltıldı
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${filteredTemplates.length}',
                style: const TextStyle(
                  fontSize: 9, // Font boyutu küçültüldı
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
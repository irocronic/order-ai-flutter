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
          // Bilgi kartları
          TemplateInfoCards(
            currentMenuItemCount: currentMenuItemCount,
            selectedTemplateIds: selectedTemplateIds,
            templateVariantConfigs: templateVariantConfigs,
          ),
          
          // Kategori seçimi
          TemplateCategoryDropdown(
            availableCategories: availableCategories,
            selectedCategoryName: selectedCategoryName,
            onCategoryChanged: onCategoryChanged,
          ),
          const SizedBox(height: 12),
          
          // Arama alanı
          if (selectedCategoryName != null) ...[
            TemplateSearchField(
              searchController: searchController,
            ),
            const SizedBox(height: 12),
          ],
          
          // Template listesi container - BURADA DEĞİŞİKLİK
          Container(
            height: keyboardHeight > 0 ? 200.0 : 350.0,
            decoration: BoxDecoration(
              // ✅ DÜZELTME: Beyaz arka plan yerine şeffaf mavi gradient
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
}
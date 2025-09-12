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
  final int? targetCategoryId; // ✅ YENİ EKLENEN
  final int businessId; // ✅ YENİ EKLENEN
  final String token; // ✅ YENİ EKLENEN
  final ScrollController? scrollController; // ✅ YENİ: Scroll controller
  final Function(String?) onCategoryChanged;
  final VoidCallback onToggleSelectAll;
  final Function(int) onToggleTemplateSelection;
  final Function(int) onToggleRecipeStatus;
  final Function(int) onOpenVariantManagement;
  final VoidCallback onShowLimitReached;
  final Function(Map<String, dynamic>) onCustomProductAdded; // ✅ YENİ EKLENEN
  final Function(int)? onEnsureItemVisible; // ✅ YENİ: Visibility callback

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
    required this.targetCategoryId, // ✅ YENİ EKLENEN
    required this.businessId, // ✅ YENİ EKLENEN
    required this.token, // ✅ YENİ EKLENEN
    this.scrollController, // ✅ YENİ: Scroll controller
    required this.onCategoryChanged,
    required this.onToggleSelectAll,
    required this.onToggleTemplateSelection,
    required this.onToggleRecipeStatus,
    required this.onOpenVariantManagement,
    required this.onShowLimitReached,
    required this.onCustomProductAdded, // ✅ YENİ EKLENEN
    this.onEnsureItemVisible, // ✅ YENİ: Visibility callback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return SingleChildScrollView(
      controller: scrollController, // ✅ YENİ: Scroll controller'ı kullan
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
          
          // Template listesi container
          Container(
            height: keyboardHeight > 0 ? 200.0 : 350.0,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6.0),
              color: Colors.grey.shade50,
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
              targetCategoryId: targetCategoryId, // ✅ YENİ EKLENEN
              businessId: businessId, // ✅ YENİ EKLENEN
              token: token, // ✅ YENİ EKLENEN
              onToggleSelectAll: onToggleSelectAll,
              onToggleTemplateSelection: onToggleTemplateSelection,
              onToggleRecipeStatus: onToggleRecipeStatus,
              onOpenVariantManagement: onOpenVariantManagement,
              onShowLimitReached: onShowLimitReached,
              onCustomProductAdded: onCustomProductAdded, // ✅ YENİ EKLENEN
              // ✅ KALDIRILDI: onEnsureItemVisible parametresi - TemplateListWidget'ta yok
            ),
          ),
        ],
      ),
    );
  }
}
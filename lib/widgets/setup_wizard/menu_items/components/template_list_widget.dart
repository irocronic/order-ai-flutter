// lib/widgets/setup_wizard/menu_items/components/template_list_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // EKLENDİ

import '../../../../services/user_session.dart';
import '../models/variant_template_config.dart';
import '../dialogs/custom_product_dialog.dart';

class TemplateListWidget extends StatelessWidget {
  final String? selectedCategoryName;
  final bool isLoadingTemplates;
  final List<dynamic> allTemplates;
  final List<dynamic> filteredTemplates;
  final List<int> selectedTemplateIds;
  final Map<int, bool> templateRecipeStatus;
  final Map<int, TextEditingController> templatePriceControllers;
  final Map<int, VariantTemplateConfig> templateVariantConfigs;
  final int currentMenuItemCount;
  final int? targetCategoryId;
  final int businessId;
  final String token;
  final VoidCallback onToggleSelectAll;
  final Function(int) onToggleTemplateSelection;
  final Function(int) onToggleRecipeStatus;
  final Function(int) onOpenVariantManagement;
  final VoidCallback onShowLimitReached;
  final Function(Map<String, dynamic>) onCustomProductAdded;

  const TemplateListWidget({
    Key? key,
    required this.selectedCategoryName,
    required this.isLoadingTemplates,
    required this.allTemplates,
    required this.filteredTemplates,
    required this.selectedTemplateIds,
    required this.templateRecipeStatus,
    required this.templatePriceControllers,
    required this.templateVariantConfigs,
    required this.currentMenuItemCount,
    required this.targetCategoryId,
    required this.businessId,
    required this.token,
    required this.onToggleSelectAll,
    required this.onToggleTemplateSelection,
    required this.onToggleRecipeStatus,
    required this.onOpenVariantManagement,
    required this.onShowLimitReached,
    required this.onCustomProductAdded,
  }) : super(key: key);

  Future<void> _openCustomProductDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!; // EKLENDİ
    if (targetCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectCategoryFirst), // GÜNCELLENDİ
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomProductDialog(
        token: token,
        businessId: businessId,
        targetCategoryId: targetCategoryId!,
        selectedCategoryName: selectedCategoryName ?? '',
      ),
    );

    if (result != null) {
      onCustomProductAdded(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // EKLENDİ
    if (selectedCategoryName == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 32, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              l10n.selectCategoryFirst, // GÜNCELLENDİ
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (isLoadingTemplates) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.loadingTemplates, // GÜNCELLENDİ
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (allTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 32, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              l10n.noTemplatesFoundForCategory, // GÜNCELLENDİ
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openCustomProductDialog(context),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(l10n.addCustomProduct), // GÜNCELLENDİ
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    if (filteredTemplates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 24, color: Colors.grey.shade500),
            const SizedBox(height: 6),
            Text(
              l10n.noProductsFoundForSearchCriteria, // GÜNCELLENDİ
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openCustomProductDialog(context),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(l10n.addCustomProduct), // GÜNCELLENDİ
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      );
    }

    final bool hasVisibleItems = filteredTemplates.isNotEmpty;
    final bool allVisibleSelected = hasVisibleItems &&
        filteredTemplates.every((template) => selectedTemplateIds.contains(template['id']));

    return Column(
      children: [
        if (hasVisibleItems)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: allVisibleSelected,
                    onChanged: (_) => onToggleSelectAll(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: Colors.blue,
                    checkColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    allVisibleSelected ? l10n.deselectAll : l10n.selectAll, // GÜNCELLENDİ
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${filteredTemplates.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (hasVisibleItems)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openCustomProductDialog(context),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(
                  l10n.addNewProduct, // GÜNCELLENDİ
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            itemCount: filteredTemplates.length,
            itemBuilder: (context, index) {
              final template = filteredTemplates[index];
              final templateId = template['id'] as int;
              final isSelected = selectedTemplateIds.contains(templateId);
              final isFromRecipe = templateRecipeStatus[templateId] ?? true;
              final priceController = templatePriceControllers[templateId];
              final variantConfig = templateVariantConfigs[templateId];
              
              final currentLimits = UserSession.limitsNotifier.value;
              int totalAfterThisSelection = currentMenuItemCount + selectedTemplateIds.length + (isSelected ? 0 : 1);
              bool wouldExceedLimit = !isSelected && totalAfterThisSelection > currentLimits.maxMenuItems;
              
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.blue.shade200 : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: Text(
                        template['name'] ?? l10n.unnamedProduct, // GÜNCELLENDİ
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: wouldExceedLimit 
                              ? Colors.grey.shade500 
                              : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: wouldExceedLimit 
                          ? Text(
                              l10n.limitWillBeExceeded, // GÜNCELLENDİ
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : null,
                      value: isSelected,
                      onChanged: wouldExceedLimit ? null : (bool? value) {
                        if (value != null) {
                          onToggleTemplateSelection(templateId);
                        }
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      activeColor: Colors.blue,
                      checkColor: Colors.white,
                      secondary: isSelected ? SizedBox(
                        width: 80,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => onToggleRecipeStatus(templateId),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isFromRecipe 
                                      ? Colors.green.shade100 
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isFromRecipe 
                                        ? Colors.green.shade300 
                                        : Colors.orange.shade300,
                                  ),
                                ),
                                child: Text(
                                  isFromRecipe ? l10n.productTypeRecipe : l10n.productTypeManual, // GÜNCELLENDİ
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isFromRecipe 
                                        ? Colors.green.shade700 
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ) : null,
                    ),
                    
                    if (isSelected && !isFromRecipe && priceController != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 12, 8),
                        child: TextFormField(
                          controller: priceController,
                          decoration: InputDecoration(
                            labelText: '${l10n.priceLabel} (${l10n.currencySymbol.trim()})', // GÜNCELLENDİ
                            hintText: l10n.menuItemPriceHint, // GÜNCELLENDİ
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            isDense: true,
                            prefixText: l10n.currencySymbol, // GÜNCELLENDİ
                          ),
                          style: const TextStyle(fontSize: 12),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))
                          ],
                          onChanged: (value) {
                            // State update will be handled by parent
                          },
                        ),
                      ),
                    
                    if (isSelected && variantConfig != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(32, 8, 12, 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tune, color: Colors.blue.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.variants, // GÜNCELLENDİ
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  if (variantConfig.variants.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.variantsAddedCount(variantConfig.variants.length), // GÜNCELLENDİ
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => onOpenVariantManagement(templateId),
                              icon: Icon(
                                variantConfig.variants.isEmpty ? Icons.add : Icons.edit,
                                size: 14,
                              ),
                              label: Text(
                                variantConfig.variants.isEmpty ? l10n.add : l10n.edit, // GÜNCELLENDİ
                                style: const TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
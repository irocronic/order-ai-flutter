// lib/widgets/setup_wizard/menu_items/components/template_list_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    if (targetCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectCategoryFirst),
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
    final l10n = AppLocalizations.of(context)!;
    if (selectedCategoryName == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 32, color: Colors.white.withOpacity(0.7)),
            const SizedBox(height: 8),
            Text(
              l10n.selectCategoryFirst,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.loadingTemplates,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
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
            Icon(Icons.inventory_2_outlined, size: 32, color: Colors.white.withOpacity(0.7)),
            const SizedBox(height: 8),
            Text(
              l10n.noTemplatesFoundForCategory,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
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
            Icon(Icons.search_off, size: 24, color: Colors.white.withOpacity(0.7)),
            const SizedBox(height: 6),
            Text(
              l10n.noProductsFoundForSearchCriteria,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ✅ GÜNCELLEME: "Yeni Ürün Ekle" butonunu kaldırdık - sadece template listesi gösteriliyor
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.05), 
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
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
              color: isSelected 
                  ? Colors.white.withOpacity(0.25)
                  : Colors.white.withOpacity(0.1),
              border: Border.all(
                color: isSelected 
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white.withOpacity(0.2),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  title: Text(
                    template['name'] ?? l10n.unnamedProduct,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: wouldExceedLimit 
                          ? Colors.white.withOpacity(0.5) 
                          : Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: wouldExceedLimit 
                      ? Text(
                          l10n.limitWillBeExceeded,
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
                  activeColor: Colors.white,
                  checkColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.white.withOpacity(0.8)),
                  secondary: isSelected ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: InkWell(
                      onTap: () => onToggleRecipeStatus(templateId),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFromRecipe 
                              ? Colors.green.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isFromRecipe 
                                ? Colors.green.withOpacity(0.5) 
                                : Colors.orange.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          isFromRecipe ? l10n.productTypeRecipe : l10n.productTypeManual,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ) : null,
                ),
                
                if (isSelected && !isFromRecipe && priceController != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 12, 8),
                    child: TextFormField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: '${l10n.priceLabel} (${l10n.currencySymbol.trim()})',
                        hintText: l10n.menuItemPriceHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.white, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        isDense: true,
                        prefixText: l10n.currencySymbol,
                        labelStyle: const TextStyle(color: Colors.white),
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        prefixStyle: const TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tune, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.variants,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (variantConfig.variants.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  l10n.variantsAddedCount(variantConfig.variants.length),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
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
                            variantConfig.variants.isEmpty ? l10n.add : l10n.edit,
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
    );
  }
}
// lib/widgets/setup_wizard/menu_items/components/template_list_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final int? targetCategoryId; // ✅ YENİ EKLENEN
  final int businessId; // ✅ YENİ EKLENEN
  final String token; // ✅ YENİ EKLENEN
  final VoidCallback onToggleSelectAll;
  final Function(int) onToggleTemplateSelection;
  final Function(int) onToggleRecipeStatus;
  final Function(int) onOpenVariantManagement;
  final VoidCallback onShowLimitReached;
  final Function(Map<String, dynamic>) onCustomProductAdded; // ✅ YENİ EKLENEN

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
    required this.targetCategoryId, // ✅ YENİ EKLENEN
    required this.businessId, // ✅ YENİ EKLENEN
    required this.token, // ✅ YENİ EKLENEN
    required this.onToggleSelectAll,
    required this.onToggleTemplateSelection,
    required this.onToggleRecipeStatus,
    required this.onOpenVariantManagement,
    required this.onShowLimitReached,
    required this.onCustomProductAdded, // ✅ YENİ EKLENEN
  }) : super(key: key);

  // ✅ YENİ EKLENEN: Özel ürün ekleme dialog'u açma
  Future<void> _openCustomProductDialog(BuildContext context) async {
    if (targetCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce bir kategori seçin'),
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
    if (selectedCategoryName == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 32, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              'Önce bir kategori seçin',
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
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Şablonlar yükleniyor...',
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
              'Bu kategori için şablon bulunamadı',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // ✅ YENİ: Şablon yoksa da özel ürün ekleyebilsin
            ElevatedButton.icon(
              onPressed: () => _openCustomProductDialog(context),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Özel Ürün Ekle'),
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
              'Arama kriterlerinize uygun\nürün bulunamadı.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // ✅ YENİ: Arama sonucu yoksa da özel ürün ekleyebilsin
            ElevatedButton.icon(
              onPressed: () => _openCustomProductDialog(context),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Özel Ürün Ekle'),
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
        // Tümünü seç butonu
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
                    allVisibleSelected ? 'Tümünü Bırak' : 'Tümünü Seç',
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

        // ✅ YENİ EKLENEN: Özel Ürün Ekle butonu
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
                label: const Text(
                  'Yeni Ürün Ekle',
                  style: TextStyle(
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
        
        // Template listesi
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
                    // Ana ürün satırı
                    CheckboxListTile(
                      title: Text(
                        template['name'] ?? 'İsimsiz Ürün',
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
                        ? const Text(
                            'Limit aşılacak',
                            style: TextStyle(
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
                                  isFromRecipe ? 'Reçeteli' : 'Manuel',
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
                    
                    // Fiyat alanı (sadece manuel ürünler için)
                    if (isSelected && !isFromRecipe && priceController != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 0, 12, 8),
                        child: TextFormField(
                          controller: priceController,
                          decoration: InputDecoration(
                            labelText: 'Fiyat (₺)',
                            hintText: 'Örn: 25.50',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            isDense: true,
                            prefixText: '₺ ',
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
                    
                    // Varyant durumu göstergesi ve yönetim butonu
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
                                    'Varyantlar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  if (variantConfig.variants.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${variantConfig.variants.length} varyant eklendi',
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
                                variantConfig.variants.isEmpty ? 'Ekle' : 'Düzenle',
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
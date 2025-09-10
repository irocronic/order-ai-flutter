// lib/widgets/setup_wizard/menu_items/dialogs/template_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

import '../../../../services/api_service.dart';
import '../../../../services/user_session.dart';
import '../../../../screens/subscription_screen.dart';

class TemplateSelectionDialog extends StatefulWidget {
  final String token;
  final List<dynamic> availableCategories;
  final int currentMenuItemCount;

  const TemplateSelectionDialog({
    Key? key,
    required this.token,
    required this.availableCategories,
    required this.currentMenuItemCount,
  }) : super(key: key);

  @override
  State<TemplateSelectionDialog> createState() => _TemplateSelectionDialogState();
}

class _TemplateSelectionDialogState extends State<TemplateSelectionDialog> {
  List<int> selectedTemplateIds = [];
  List<dynamic> allTemplates = [];
  List<dynamic> filteredTemplates = [];
  final TextEditingController _searchController = TextEditingController();
  
  String? _selectedCategoryName;
  int? _targetCategoryId;
  bool _isLoadingTemplates = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterTemplates);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTemplates);
    _searchController.dispose();
    super.dispose();
  }

  void _filterTemplates() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        filteredTemplates = allTemplates;
      } else {
        filteredTemplates = allTemplates.where((template) {
          final name = template['name']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadTemplatesForCategory(String categoryName) async {
    if (!mounted) return;
    setState(() => _isLoadingTemplates = true);
    
    try {
      final templates = await ApiService.fetchMenuItemTemplates(
        widget.token,
        categoryTemplateName: categoryName,
      );
      
      if (mounted) {
        setState(() {
          allTemplates = templates;
          filteredTemplates = templates;
          selectedTemplateIds.clear();
          _searchController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şablonlar yüklenirken hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  void _toggleTemplateSelection(int templateId) {
    final currentLimits = UserSession.limitsNotifier.value;
    
    setState(() {
      if (selectedTemplateIds.contains(templateId)) {
        selectedTemplateIds.remove(templateId);
      } else {
        int totalAfterSelection = widget.currentMenuItemCount + selectedTemplateIds.length + 1;
        
        if (totalAfterSelection > currentLimits.maxMenuItems) {
          _showLimitReachedDialog();
          return;
        }
        
        selectedTemplateIds.add(templateId);
      }
    });
  }

  void _toggleSelectAll() {
    final currentLimits = UserSession.limitsNotifier.value;
    
    setState(() {
      final allCurrentVisible = filteredTemplates.map((t) => t['id'] as int).toSet();
      final hasAllSelected = allCurrentVisible.every((id) => selectedTemplateIds.contains(id));
      
      if (hasAllSelected) {
        selectedTemplateIds.removeWhere((id) => allCurrentVisible.contains(id));
      } else {
        final newSelections = allCurrentVisible.where((id) => !selectedTemplateIds.contains(id)).toList();
        int totalAfterAllSelection = widget.currentMenuItemCount + selectedTemplateIds.length + newSelections.length;
        
        if (totalAfterAllSelection > currentLimits.maxMenuItems) {
          _showLimitReachedDialog();
          return;
        }
        
        selectedTemplateIds.addAll(newSelections);
      }
    });
  }

  void _showLimitReachedDialog() {
    final currentLimits = UserSession.limitsNotifier.value;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogLimitReachedTitle),
        content: Text(l10n.createMenuItemErrorLimitExceeded(currentLimits.maxMenuItems.toString())),
        actions: [
          TextButton(
            child: Text(l10n.dialogButtonLater),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text(l10n.dialogButtonUpgradePlan),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    final availableHeight = screenHeight - keyboardHeight - 100.0;
    final dialogHeight = availableHeight > 300.0 ? availableHeight : 300.0;
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? screenWidth * 0.1 : 16.0,
        vertical: keyboardHeight > 0 ? 20.0 : 40.0,
      ),
      child: Container(
        width: screenWidth > 600 ? 500 : double.infinity,
        height: dialogHeight,
        child: Column(
          children: [
            // Header - Sabit yükseklik
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  topRight: Radius.circular(4.0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Şablondan Ürün Ekle',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            
            // Content - Scrollable area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Limit bilgisi
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      margin: const EdgeInsets.only(bottom: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Mevcut: ${widget.currentMenuItemCount}, Seçilen: ${selectedTemplateIds.length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 🎨 DÜZELTİLDİ: Kategori seçimi - Renk sorunu çözüldü
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryName,
                      isExpanded: true,
                      // 🎨 EKLENDI: Dropdown menu renkleri
                      dropdownColor: Colors.white, // Dropdown arka plan beyaz
                      iconEnabledColor: Colors.grey.shade600, // Icon rengi
                      decoration: const InputDecoration(
                        labelText: 'Kategori Seçin',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        isDense: true,
                        // 🎨 EKLENDI: Label ve border renkleri
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      // 🎨 DÜZELTİLDİ: Seçili item text rengi
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87, // Ana text siyah
                        fontWeight: FontWeight.w500,
                      ),
                      items: widget.availableCategories.map<DropdownMenuItem<String>>((category) {
                        return DropdownMenuItem<String>(
                          value: category['name'],
                          child: Container(
                            // 🎨 EKLENDI: Item container styling
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              category['name'] ?? 'Bilinmeyen Kategori',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87, // 🎨 DÜZELTİLDİ: Text rengi siyah
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (categoryName) {
                        if (categoryName != null) {
                          final selectedCategory = widget.availableCategories.firstWhereOrNull(
                            (cat) => cat['name'] == categoryName,
                          );
                          setState(() {
                            _selectedCategoryName = categoryName;
                            _targetCategoryId = selectedCategory?['id'];
                          });
                          _loadTemplatesForCategory(categoryName);
                        }
                      },
                      // 🎨 EKLENDI: Dropdown buton renk ayarları
                      hint: const Text(
                        'Kategori seçiniz...',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 🎨 DÜZELTİLDİ: Arama alanı - Renk iyileştirmesi
                    if (_selectedCategoryName != null) ...[
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Ürün Ara',
                          hintText: 'Ürün adı ile ara...',
                          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade600), // 🎨 EKLENDI
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          isDense: true,
                          // 🎨 EKLENDI: Label ve border renkleri
                          labelStyle: const TextStyle(color: Colors.grey),
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.blue, width: 2),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 16, color: Colors.grey.shade600), // 🎨 EKLENDI
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                        ),
                        // 🎨 DÜZELTİLDİ: Arama text rengi
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Template listesi container
                    Container(
                      height: keyboardHeight > 0 ? 150.0 : 250.0,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6.0),
                        // 🎨 EKLENDI: Liste arka plan rengi
                        color: Colors.grey.shade50,
                      ),
                      child: _buildTemplateList(),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer - Sabit yükseklik
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4.0),
                  bottomRight: Radius.circular(4.0),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.dialogButtonCancel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700, // 🎨 EKLENDI
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedTemplateIds.isNotEmpty && _targetCategoryId != null
                          ? () => Navigator.of(context).pop({
                              'selectedTemplateIds': selectedTemplateIds,
                              'targetCategoryId': _targetCategoryId,
                              'count': selectedTemplateIds.length,
                            })
                          : null,
                      // 🎨 EKLENDI: Button styling
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        '${selectedTemplateIds.length} ürün - Ekle',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // 🎨 EKLENDI
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 DÜZELTİLDİ: Template list renk iyileştirmeleri
  Widget _buildTemplateList() {
    if (_selectedCategoryName == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 32, color: Colors.grey.shade500), // 🎨 EKLENDI
            const SizedBox(height: 8),
            Text(
              'Önce bir kategori seçin',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600, // 🎨 DÜZELTİLDİ
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isLoadingTemplates) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), // 🎨 EKLENDI
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Şablonlar yükleniyor...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600, // 🎨 DÜZELTİLDİ
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
            Icon(Icons.inventory_2_outlined, size: 32, color: Colors.grey.shade500), // 🎨 EKLENDI
            const SizedBox(height: 8),
            Text(
              'Bu kategori için şablon bulunamadı',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600, // 🎨 DÜZELTİLDİ
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
            Icon(Icons.search_off, size: 24, color: Colors.grey.shade500), // 🎨 EKLENDI
            const SizedBox(height: 6),
            Text(
              'Arama kriterlerinize uygun\nürün bulunamadı.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600, // 🎨 DÜZELTİLDİ
              ),
              textAlign: TextAlign.center,
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
        // 🎨 DÜZELTİLDİ: Tümünü seç butonu renk iyileştirmesi
        if (hasVisibleItems)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white, // 🎨 EKLENDI: Beyaz arka plan
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300), // 🎨 EKLENDI
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: allVisibleSelected,
                    onChanged: (_) => _toggleSelectAll(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    // 🎨 EKLENDI: Checkbox renkleri
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
                      color: Colors.black87, // 🎨 DÜZELTİLDİ
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  // 🎨 EKLENDI: Sayı badge
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${filteredTemplates.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700, // 🎨 DÜZELTİLDİ
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
              
              final currentLimits = UserSession.limitsNotifier.value;
              int totalAfterThisSelection = widget.currentMenuItemCount + selectedTemplateIds.length + (isSelected ? 0 : 1);
              bool wouldExceedLimit = !isSelected && totalAfterThisSelection > currentLimits.maxMenuItems;
              
              return Container(
                // 🎨 EKLENDI: List item container styling
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.blue.shade200 : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CheckboxListTile(
                  title: Text(
                    template['name'] ?? 'İsimsiz Ürün',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: wouldExceedLimit 
                          ? Colors.grey.shade500 
                          : Colors.black87, // 🎨 DÜZELTİLDİ
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
                      _toggleTemplateSelection(templateId);
                    }
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  // 🎨 EKLENDI: Checkbox renkleri
                  activeColor: Colors.blue,
                  checkColor: Colors.white,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
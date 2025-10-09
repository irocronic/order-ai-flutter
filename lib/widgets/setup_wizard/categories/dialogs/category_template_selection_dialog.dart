// lib/widgets/setup_wizard/categories/dialogs/category_template_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../models/kds_screen_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/kds_management_service.dart';
import '../../../../services/user_session.dart';
import '../../../../screens/subscription_screen.dart';
import '../../../../services/localized_template_service.dart';
import '../../../../providers/language_provider.dart';

class CategoryTemplateSelectionDialog extends StatefulWidget {
  final Function(List<int> templateIds, int? kdsScreenId) onConfirm;

  const CategoryTemplateSelectionDialog({
    Key? key,
    required this.onConfirm,
  }) : super(key: key);

  @override
  _CategoryTemplateSelectionDialogState createState() =>
      _CategoryTemplateSelectionDialogState();
}

class _CategoryTemplateSelectionDialogState
    extends State<CategoryTemplateSelectionDialog> {
  final _formKey = GlobalKey<FormState>();

  List<dynamic> _allTemplates = [];
  List<dynamic> _filteredTemplates = [];
  final TextEditingController _searchController = TextEditingController();

  final List<int> _selectedTemplates = [];
  List<KdsScreenModel> _kdsScreens = [];
  
  // 🔥 YENİ: Her template için ayrı KDS seçimi
  Map<int, int?> _templateKdsMap = {};
  
  bool _isLoading = true;
  bool _isSubmitting = false;

  int _currentCategoryCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _searchController.addListener(_filterTemplates);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTemplates);
    _searchController.dispose();
    super.dispose();
  }

  // 🎨 YENİ: Icon mapping fonksiyonu
  IconData _getIconFromName(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return Icons.category_outlined;
    }
    
    // Material Icons mapping
    final iconMap = <String, IconData>{
      'restaurant': Icons.restaurant,
      'soup_kitchen': Icons.soup_kitchen,
      'local_dining': Icons.local_dining,
      'local_fire_department': Icons.local_fire_department,
      'eco': Icons.eco,
      'cake': Icons.cake,
      'wine_bar': Icons.wine_bar,
      'local_drink': Icons.local_drink,
      'local_cafe': Icons.local_cafe,
      'fastfood': Icons.fastfood,
      'lunch_dining': Icons.lunch_dining,
      'dinner_dining': Icons.dinner_dining,
      'breakfast_dining': Icons.breakfast_dining,
      'icecream': Icons.icecream,
      'coffee': Icons.coffee,
      'liquor': Icons.liquor,
      'local_pizza': Icons.local_pizza,
      'rice_bowl': Icons.rice_bowl,
      'ramen_dining': Icons.ramen_dining,
      'bakery_dining': Icons.bakery_dining,
      'brunch_dining': Icons.brunch_dining,
      'tapas': Icons.tapas,
      'kebab_dining': Icons.kebab_dining,
      'set_meal': Icons.set_meal,
      'outdoor_grill': Icons.outdoor_grill,
      'emoji_food_beverage': Icons.emoji_food_beverage,
      'free_breakfast': Icons.free_breakfast,
      'kitchen': Icons.kitchen,
      'microwave': Icons.microwave,
      'blender': Icons.blender,
      'food_bank': Icons.food_bank,
      'delivery_dining': Icons.delivery_dining,
      'takeout_dining': Icons.takeout_dining,
      'room_service': Icons.room_service,
      'menu_book': Icons.menu_book,
      'restaurant_menu': Icons.restaurant_menu,
      'no_food': Icons.no_food,
      'no_drinks': Icons.no_drinks,
      'sports_bar': Icons.sports_bar,
      'nightlife': Icons.nightlife,
      'branding_watermark': Icons.branding_watermark,
    };
    
    return iconMap[iconName.toLowerCase()] ?? Icons.category_outlined;
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 🔥 ÖNEMLİ DEĞİŞİKLİK: Dinamik dil kodu kullanımı
      final languageCode = LanguageProvider.currentLanguageCode;
      debugPrint('🌐 Template yükleme - Güncel dil kodu: $languageCode');
      
      final templates = await LocalizedTemplateService.loadCategories(languageCode);
      debugPrint('📁 $languageCode dili için ${templates.length} kategori template\'i yüklendi');

      final results = await Future.wait([
        KdsManagementService.fetchKdsScreens(UserSession.token, UserSession.businessId!),
      ]);

      setState(() {
        _allTemplates = templates;
        _filteredTemplates = _allTemplates;
        _kdsScreens = (results[0] as List<KdsScreenModel>).where((kds) => kds.isActive).toList();
        
        // 🔥 YENİ: Her template için KDS mapping'i başlat
        _templateKdsMap = {};
        for (final template in _allTemplates) {
          _templateKdsMap[template['id']] = null;
        }
      });
      
      debugPrint('✅ Template yükleme başarılı: ${_allTemplates.length} kategori');
      
    } catch (e) {
      debugPrint('❌ Template yükleme hatası: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorLoadingData(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterTemplates() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredTemplates = _allTemplates;
      } else {
        _filteredTemplates = _allTemplates.where((template) {
          final name = template['name']?.toString().toLowerCase() ?? '';
          final iconName = template['icon_name']?.toString().toLowerCase() ?? '';
          return name.contains(query) || iconName.contains(query);
        }).toList();
      }
    });
  }

  void _showLimitReachedDialog(String message) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(l10n.dialogLimitReachedTitle),
              content: Text(message),
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

  void _toggleTemplateSelection(int templateId) {
    setState(() {
      if (_selectedTemplates.contains(templateId)) {
        _selectedTemplates.remove(templateId);
      } else {
        _selectedTemplates.add(templateId);
      }
      _formKey.currentState?.validate();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final allCurrentVisible = _filteredTemplates.map((t) => t['id'] as int).toSet();
      final hasAllSelected = allCurrentVisible.every((id) => _selectedTemplates.contains(id));
      if (hasAllSelected) {
        _selectedTemplates.removeWhere((id) => allCurrentVisible.contains(id));
      } else {
        final newSelections = allCurrentVisible.where((id) => !_selectedTemplates.contains(id)).toList();
        _selectedTemplates.addAll(newSelections);
      }
      _formKey.currentState?.validate();
    });
  }

  // 🔥 YENİ: KDS seçimini güncelle
  void _updateTemplateKds(int templateId, int? kdsId) {
    setState(() {
      _templateKdsMap[templateId] = kdsId;
    });
  }

  // 🔥 YENİ: KDS seçimi validasyonu
  bool _validateKdsSelections() {
    for (final templateId in _selectedTemplates) {
      if (_templateKdsMap[templateId] == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveSelectedTemplatesManually(
      BuildContext context, List<int> selectedIds) async {
    final l10n = AppLocalizations.of(context)!;
    final token = UserSession.token;
    final businessId = UserSession.businessId!;
    
    try {
      for (final template in _allTemplates.where((t) => selectedIds.contains(t['id']))) {
        final templateId = template['id'];
        final kdsScreenId = _templateKdsMap[templateId];
        
        await ApiService.createCategoryForBusiness(
          token,
          businessId,
          template['name'] ?? '',
          null,
          null,
          kdsScreenId,
          template['kdv_rate'] is num
              ? (template['kdv_rate'] as num).toDouble()
              : (template['kdv_rate'] != null
                  ? double.tryParse(template['kdv_rate'].toString()) ?? 10.0
                  : 10.0),
        );
      }
      
      if (mounted) {
        Navigator.of(context).pop({
          'success': true,
          'message': l10n.setupCategoriesSuccessFromTemplate,
          'count': selectedIds.length,
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop({
          'success': false,
          'message': l10n.setupCategoriesErrorFromTemplate(e.toString()),
        });
      }
    }
  }

  void _createCategories() {
    final l10n = AppLocalizations.of(context)!;
    
    // 🔥 YENİ: KDS seçim validasyonu kontrolü
    if (_selectedTemplates.isNotEmpty && !_validateKdsSelections()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.kdsSelectionRequiredError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);

    _saveSelectedTemplatesManually(context, _selectedTemplates);
  }

  // 🔥 YENİ: KDS Dropdown Widget'ı - güncellendi ve responsive yapıldı
  Widget _buildKdsDropdownForTemplate(int templateId, AppLocalizations l10n) {
    final isSelected = _selectedTemplates.contains(templateId);
    final hasError = isSelected && _templateKdsMap[templateId] == null;
    
    return Container(
      constraints: BoxConstraints(
        minWidth: 120,
        maxWidth: 180,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError 
              ? Colors.red.withOpacity(0.8) 
              : Colors.white.withOpacity(0.2),
          width: hasError ? 2 : 1,
        ),
      ),
      child: DropdownButtonFormField<int?>(
        value: _templateKdsMap[templateId],
        isExpanded: true,
        dropdownColor: Colors.blue.shade800,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: InputDecoration(
          hintText: isSelected 
              ? l10n.kdsRequired
              : l10n.kdsScreenNotSelected,
          hintStyle: TextStyle(
            color: isSelected 
                ? Colors.red.withOpacity(0.9) 
                : Colors.white.withOpacity(0.6), 
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          isDense: true,
        ),
        icon: Icon(
          Icons.arrow_drop_down, 
          color: hasError 
              ? Colors.red.withOpacity(0.8) 
              : Colors.white.withOpacity(0.8), 
          size: 14
        ),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text(
              l10n.kdsScreenNotSelected,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7), 
                fontSize: 10
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ..._kdsScreens.map((kds) {
            return DropdownMenuItem<int?>(
              value: kds.id,
              child: Text(
                kds.name,
                style: const TextStyle(fontSize: 10, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ],
        onChanged: (value) {
          _updateTemplateKds(templateId, value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    final availableHeight = screenHeight - keyboardHeight - 100.0;
    final double dialogHeight = availableHeight > 400.0 ? availableHeight : 400.0;

    final bool hasVisibleItems = _filteredTemplates.isNotEmpty;
    final bool allVisibleSelected = hasVisibleItems &&
        _filteredTemplates.every((template) => _selectedTemplates.contains(template['id']));
    
    // 🔥 YENİ: KDS validasyon durumu
    final bool hasKdsValidationError = _selectedTemplates.isNotEmpty && !_validateKdsSelections();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? screenWidth * 0.2 : 16.0,
        vertical: keyboardHeight > 0 ? 8.0 : 24.0,
      ),
      child: Container(
        width: screenWidth > 600 ? 700 : double.infinity,
        height: dialogHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1565C0), // Koyu mavi
              const Color(0xFF1976D2), // Orta mavi
              const Color(0xFF1E88E5), // Açık mavi
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with gradient and glass effect
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.category_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.setupCategoriesSelectFromTemplate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                ],
              ),
            ),

            // Content with glass effect
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.templatesLoading,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🔥 YENİ: Responsive tümünü seç/bırak butonu ve arama alanı
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Ekran genişliğine göre layout belirleme
                                    if (constraints.maxWidth < 400) {
                                      // Dar ekranlar için dikey layout
                                      return Column(
                                        children: [
                                          // Tümünü seç/bırak butonu
                                          if (hasVisibleItems)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.2),
                                                ),
                                              ),
                                              child: InkWell(
                                                onTap: _toggleSelectAll,
                                                child: Row(
                                                  children: [
                                                    Checkbox(
                                                      value: allVisibleSelected,
                                                      onChanged: (_) => _toggleSelectAll(),
                                                      activeColor: Colors.white,
                                                      checkColor: Colors.blue.shade800,
                                                      side: BorderSide(color: Colors.white.withOpacity(0.7)),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            allVisibleSelected ? l10n.deselectAll : l10n.selectAll,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold, 
                                                              fontSize: 14,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                          Text(
                                                            l10n.templatesDisplayed(_filteredTemplates.length),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.white.withOpacity(0.7),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          
                                          if (hasVisibleItems) const SizedBox(height: 12),

                                          // Arama alanı
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.3),
                                              ),
                                            ),
                                            child: TextField(
                                              controller: _searchController,
                                              style: const TextStyle(color: Colors.white, fontSize: 14),
                                              decoration: InputDecoration(
                                                labelText: l10n.searchCategoryTemplateLabel,
                                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                                hintText: l10n.searchCategoryTemplateHint,
                                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8), size: 20),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                suffixIcon: _searchController.text.isNotEmpty
                                                    ? IconButton(
                                                        icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.8), size: 18),
                                                        onPressed: () {
                                                          _searchController.clear();
                                                        },
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      // Geniş ekranlar için yatay layout
                                      return Row(
                                        children: [
                                          // Tümünü seç/bırak butonu
                                          if (hasVisibleItems)
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.white.withOpacity(0.2),
                                                  ),
                                                ),
                                                child: InkWell(
                                                  onTap: _toggleSelectAll,
                                                  child: Row(
                                                    children: [
                                                      Checkbox(
                                                        value: allVisibleSelected,
                                                        onChanged: (_) => _toggleSelectAll(),
                                                        activeColor: Colors.white,
                                                        checkColor: Colors.blue.shade800,
                                                        side: BorderSide(color: Colors.white.withOpacity(0.7)),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              allVisibleSelected ? l10n.deselectAll : l10n.selectAll,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.bold, 
                                                                fontSize: 14,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                            Text(
                                                              l10n.templatesDisplayed(_filteredTemplates.length),
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.white.withOpacity(0.7),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          
                                          if (hasVisibleItems) const SizedBox(width: 12),

                                          // Arama alanı
                                          Expanded(
                                            flex: 3,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.3),
                                                ),
                                              ),
                                              child: TextField(
                                                controller: _searchController,
                                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                                decoration: InputDecoration(
                                                  labelText: l10n.searchCategoryTemplateLabel,
                                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                                  hintText: l10n.searchCategoryTemplateHint,
                                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8), size: 20),
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  suffixIcon: _searchController.text.isNotEmpty
                                                      ? IconButton(
                                                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.8), size: 18),
                                                          onPressed: () {
                                                            _searchController.clear();
                                                          },
                                                        )
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                                
                                const SizedBox(height: 16),

                                // 🔥 YENİ: KDS seçim hatası uyarısı
                                if (hasKdsValidationError)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning,
                                          color: Colors.red.withOpacity(0.8),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.kdsSelectionRequiredError,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // 🔥 YENİ: Template listesi header - responsive
                                if (hasVisibleItems)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                l10n.categoryName,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white.withOpacity(0.9),
                                                ),
                                              ),
                                            ),
                                            // KDS column header sadece yeterli alan varsa göster
                                            if (constraints.maxWidth > 300)
                                              SizedBox(
                                                width: 120,
                                                child: Text(
                                                  l10n.kdsScreen,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white.withOpacity(0.9),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),

                                // Template listesi - responsive
                                Container(
                                  height: keyboardHeight > 0 ? 220.0 : 320.0,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: _allTemplates.isEmpty
                                      ? Center(
                                          child: Text(
                                            l10n.noTemplatesFound,
                                            style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                          ),
                                        )
                                      : _filteredTemplates.isEmpty
                                          ? Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.search_off, 
                                                    size: 48, 
                                                    color: Colors.white.withOpacity(0.6)
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    l10n.noTemplatesMatchSearch,
                                                    style: TextStyle(
                                                      fontSize: 14, 
                                                      color: Colors.white.withOpacity(0.8)
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            )
                                          : ListView.builder(
                                              padding: const EdgeInsets.all(8.0),
                                              itemCount: _filteredTemplates.length,
                                              itemBuilder: (context, index) {
                                                final template = _filteredTemplates[index];
                                                final templateId = template['id'] as int;
                                                final bool isSelected = _selectedTemplates.contains(templateId);
                                                
                                                return Container(
                                                  margin: const EdgeInsets.only(bottom: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSelected 
                                                        ? Colors.white.withOpacity(0.2)
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isSelected 
                                                          ? Colors.white.withOpacity(0.4)
                                                          : Colors.transparent,
                                                    ),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    child: LayoutBuilder(
                                                      builder: (context, constraints) {
                                                        // Dar ekranlarda farklı layout
                                                        if (constraints.maxWidth < 300) {
                                                          return Column(
                                                            children: [
                                                              // Template bilgisi
                                                              Row(
                                                                children: [
                                                                  Checkbox(
                                                                    value: isSelected,
                                                                    onChanged: (bool? value) {
                                                                      if (value != null) {
                                                                        _toggleTemplateSelection(templateId);
                                                                      }
                                                                    },
                                                                    activeColor: Colors.white,
                                                                    checkColor: Colors.blue.shade800,
                                                                    side: BorderSide(color: Colors.white.withOpacity(0.7)),
                                                                  ),
                                                                  const SizedBox(width: 8),
                                                                  
                                                                  // Icon
                                                                  Container(
                                                                    padding: const EdgeInsets.all(6),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors.white.withOpacity(0.15),
                                                                      borderRadius: BorderRadius.circular(6),
                                                                    ),
                                                                    child: Icon(
                                                                      _getIconFromName(template['icon_name']),
                                                                      size: 18,
                                                                      color: Colors.white.withOpacity(0.9),
                                                                    ),
                                                                  ),
                                                                  
                                                                  const SizedBox(width: 8),
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        Text(
                                                                          template['name'] ?? '...',
                                                                          style: const TextStyle(
                                                                            fontWeight: FontWeight.w500,
                                                                            fontSize: 12,
                                                                            color: Colors.white,
                                                                          ),
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                        if (template['icon_name'] != null && 
                                                                            template['icon_name'].toString().isNotEmpty) ...[
                                                                          const SizedBox(height: 2),
                                                                          Text(
                                                                            '${template['icon_name']}',
                                                                            style: TextStyle(
                                                                              fontSize: 9,
                                                                              color: Colors.white.withOpacity(0.7),
                                                                              fontStyle: FontStyle.italic,
                                                                            ),
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ],
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              
                                                              // KDS seçimi
                                                              if (isSelected) ...[
                                                                const SizedBox(height: 8),
                                                                _buildKdsDropdownForTemplate(templateId, l10n),
                                                              ],
                                                            ],
                                                          );
                                                        } else {
                                                          // Normal layout
                                                          return Row(
                                                            children: [
                                                              // Template bilgisi
                                                              Expanded(
                                                                child: Row(
                                                                  children: [
                                                                    Checkbox(
                                                                      value: isSelected,
                                                                      onChanged: (bool? value) {
                                                                        if (value != null) {
                                                                          _toggleTemplateSelection(templateId);
                                                                        }
                                                                      },
                                                                      activeColor: Colors.white,
                                                                      checkColor: Colors.blue.shade800,
                                                                      side: BorderSide(color: Colors.white.withOpacity(0.7)),
                                                                    ),
                                                                    const SizedBox(width: 8),
                                                                    
                                                                    // Icon
                                                                    Container(
                                                                      padding: const EdgeInsets.all(6),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.white.withOpacity(0.15),
                                                                        borderRadius: BorderRadius.circular(6),
                                                                      ),
                                                                      child: Icon(
                                                                        _getIconFromName(template['icon_name']),
                                                                        size: 20,
                                                                        color: Colors.white.withOpacity(0.9),
                                                                      ),
                                                                    ),
                                                                    
                                                                    const SizedBox(width: 8),
                                                                    Expanded(
                                                                      child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          Text(
                                                                            template['name'] ?? '...',
                                                                            style: const TextStyle(
                                                                              fontWeight: FontWeight.w500,
                                                                              fontSize: 13,
                                                                              color: Colors.white,
                                                                            ),
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                          if (template['icon_name'] != null && 
                                                                              template['icon_name'].toString().isNotEmpty) ...[
                                                                            const SizedBox(height: 2),
                                                                            Text(
                                                                              '${template['icon_name']}',
                                                                              style: TextStyle(
                                                                                fontSize: 10,
                                                                                color: Colors.white.withOpacity(0.7),
                                                                                fontStyle: FontStyle.italic,
                                                                              ),
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                          ],
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              
                                                              // KDS dropdown
                                                              _buildKdsDropdownForTemplate(templateId, l10n),
                                                            ],
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            // Footer/Actions with gradient
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16.0),
                  bottomRight: Radius.circular(16.0),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel button
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.9),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                      ),
                      child: Text(
                        l10n.dialogButtonCancel, 
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)
                      ),
                    ),
                    
                    // Create button
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: ElevatedButton(
                          onPressed: (_selectedTemplates.isEmpty || _isSubmitting || hasKdsValidationError) ? null : _createCategories,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue.shade700,
                            disabledBackgroundColor: Colors.white.withOpacity(0.3),
                            disabledForegroundColor: Colors.white.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                          child: _isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(l10n.creating)
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_circle_outline, size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        l10n.createTemplateButtonWithCount(_selectedTemplates.length),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
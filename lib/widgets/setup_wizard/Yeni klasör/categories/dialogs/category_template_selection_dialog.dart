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
  int? _selectedKdsScreenId;
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

  Future<void> _saveSelectedTemplatesManually(
      BuildContext context, List<int> selectedIds, int? kdsScreenId) async {
    final l10n = AppLocalizations.of(context)!;
    final token = UserSession.token;
    final businessId = UserSession.businessId!;
    
    try {
      for (final template in _allTemplates.where((t) => selectedIds.contains(t['id']))) {
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);

    _saveSelectedTemplatesManually(context, _selectedTemplates, _selectedKdsScreenId);
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? screenWidth * 0.2 : 16.0,
        vertical: keyboardHeight > 0 ? 8.0 : 24.0,
      ),
      child: Container(
        width: screenWidth > 600 ? 600 : double.infinity,
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
                            'Şablonlar yükleniyor...',
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
                                const SizedBox(height: 16),

                                // Tümünü seç/bırak
                                if (hasVisibleItems)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      title: Text(
                                        allVisibleSelected ? l10n.deselectAll : l10n.selectAll,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Text(
                                        l10n.templatesDisplayed(_filteredTemplates.length),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                      value: allVisibleSelected,
                                      onChanged: (_) => _toggleSelectAll(),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      activeColor: Colors.white,
                                      checkColor: Colors.blue.shade800,
                                      side: BorderSide(color: Colors.white.withOpacity(0.7)),
                                    ),
                                  ),

                                const SizedBox(height: 16),

                                // KDS seçimi
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedKdsScreenId,
                                    isExpanded: true,
                                    dropdownColor: Colors.blue.shade800,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText: l10n.kdsScreenLabelRequired,
                                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(Icons.kitchen_outlined, color: Colors.white.withOpacity(0.8), size: 20),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    hint: Text(
                                      l10n.kdsScreenNotSelected, 
                                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)
                                    ),
                                    icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.8)),
                                    items: _kdsScreens.map((kds) {
                                      return DropdownMenuItem<int>(
                                        value: kds.id,
                                        child: Text(
                                          kds.name, 
                                          overflow: TextOverflow.ellipsis, 
                                          style: const TextStyle(fontSize: 14)
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _selectedKdsScreenId = value);
                                    },
                                    validator: (value) {
                                      if (_selectedTemplates.isNotEmpty && value == null) {
                                        return l10n.kdsScreenValidator;
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                                if (hasVisibleItems) const SizedBox(height: 16),

                                // Template listesi
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
                                                final bool isSelected = _selectedTemplates.contains(template['id']);
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
                                                  child: CheckboxListTile(
                                                    title: Text(
                                                      template['name'] ?? '...',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    subtitle: template['icon_name'] != null && template['icon_name'].toString().isNotEmpty
                                                        ? Text(
                                                            l10n.iconInfo(template['icon_name']),
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.white.withOpacity(0.7),
                                                            ),
                                                          )
                                                        : null,
                                                    value: isSelected,
                                                    onChanged: (bool? value) {
                                                      if (value != null) {
                                                        _toggleTemplateSelection(template['id']);
                                                      }
                                                    },
                                                    controlAffinity: ListTileControlAffinity.leading,
                                                    dense: true,
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                    activeColor: Colors.white,
                                                    checkColor: Colors.blue.shade800,
                                                    side: BorderSide(color: Colors.white.withOpacity(0.7)),
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
                          onPressed: _selectedTemplates.isEmpty || _isSubmitting ? null : _createCategories,
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
                                    const Text('Oluşturuluyor...')
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
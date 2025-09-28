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
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? screenWidth * 0.2 : 16.0,
        vertical: keyboardHeight > 0 ? 8.0 : 24.0,
      ),
      child: Container(
        width: screenWidth > 600 ? 600 : double.infinity,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      l10n.setupCategoriesSelectFromTemplate,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Arama alanı
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: l10n.searchCategoryTemplateLabel,
                                  hintText: l10n.searchCategoryTemplateHint,
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  isDense: true,
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                          },
                                        )
                                      : null,
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 12),

                              // Tümünü seç/bırak
                              if (hasVisibleItems)
                                CheckboxListTile(
                                  title: Text(
                                    allVisibleSelected ? l10n.deselectAll : l10n.selectAll,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    l10n.templatesDisplayed(_filteredTemplates.length),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  value: allVisibleSelected,
                                  onChanged: (_) => _toggleSelectAll(),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),

                              // KDS seçimi
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                                child: DropdownButtonFormField<int>(
                                  value: _selectedKdsScreenId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: l10n.kdsScreenLabelRequired,
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.kitchen_outlined, size: 18),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    isDense: true,
                                  ),
                                  hint: Text(l10n.kdsScreenNotSelected, style: const TextStyle(fontSize: 13)),
                                  style: const TextStyle(fontSize: 13, color: Colors.black),
                                  items: _kdsScreens.map((kds) {
                                    return DropdownMenuItem<int>(
                                      value: kds.id,
                                      child: Text(kds.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
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

                              if (hasVisibleItems) const Divider(height: 12),

                              // Template listesi
                              Container(
                                height: keyboardHeight > 0 ? 200.0 : 300.0,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: _allTemplates.isEmpty
                                    ? Center(child: Text(l10n.noTemplatesFound))
                                    : _filteredTemplates.isEmpty
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.search_off, size: 32, color: Colors.grey),
                                                SizedBox(height: 6),
                                                Text(
                                                  l10n.noTemplatesMatchSearch,
                                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.all(4.0),
                                            itemCount: _filteredTemplates.length,
                                            itemBuilder: (context, index) {
                                              final template = _filteredTemplates[index];
                                              final bool isSelected = _selectedTemplates.contains(template['id']);
                                              return CheckboxListTile(
                                                title: Text(
                                                  template['name'] ?? '...',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                subtitle: template['icon_name'] != null && template['icon_name'].toString().isNotEmpty
                                                    ? Text(
                                                        l10n.iconInfo(template['icon_name']),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey.shade600,
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
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              );
                                            },
                                          ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            // Footer/Actions
            Container(
              height: 60,
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n.dialogButtonCancel, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedTemplates.isEmpty || _isSubmitting ? null : _createCategories,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              l10n.createTemplateButtonWithCount(_selectedTemplates.length),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
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
}
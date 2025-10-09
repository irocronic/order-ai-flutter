// lib/widgets/setup_wizard/menu_items/dialogs/template_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

import '../../../../services/user_session.dart';
import '../../../../screens/subscription_screen.dart';
import '../../../../models/menu_item_variant.dart';
import '../models/variant_template_config.dart';
import '../services/template_selection_service.dart';
import '../components/template_selection_header.dart';
import '../components/template_selection_content.dart';
import '../components/template_selection_footer.dart';
import '../dialogs/custom_product_dialog.dart';
import 'variant_management_dialog.dart';

class TemplateSelectionDialog extends StatefulWidget {
  final String token;
  final List<dynamic> availableCategories;
  final int currentMenuItemCount;
  final int businessId;

  const TemplateSelectionDialog({
    Key? key,
    required this.token,
    required this.availableCategories,
    required this.currentMenuItemCount,
    required this.businessId,
  }) : super(key: key);

  @override
  State<TemplateSelectionDialog> createState() => _TemplateSelectionDialogState();
}

class _TemplateSelectionDialogState extends State<TemplateSelectionDialog> {
  late final TemplateSelectionService _service;

  // State variables
  List<int> selectedTemplateIds = [];
  List<dynamic> allTemplates = [];
  List<dynamic> filteredTemplates = [];
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  // Reçete özelliği için state'ler
  Map<int, bool> templateRecipeStatus = {}; // templateId -> isFromRecipe
  Map<int, TextEditingController> templatePriceControllers = {}; // templateId -> price controller

  // Varyant yönetimi için state'ler
  Map<int, VariantTemplateConfig> templateVariantConfigs = {}; // templateId -> variant config

  // Hızlı varyant ekleme için state'ler
  List<dynamic> _variantTemplates = [];
  bool _isLoadingVariantTemplates = false;

  String? _selectedCategoryName;
  int? _targetCategoryId;
  bool _isLoadingTemplates = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _service = TemplateSelectionService(widget.token);
    _searchController.addListener(_filterTemplates);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTemplates);
    _searchController.dispose();
    _scrollController.dispose();

    for (var controller in templatePriceControllers.values) {
      controller.dispose();
    }
    for (var config in templateVariantConfigs.values) {
      config.dispose();
    }
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
      final templates = await _service.fetchTemplatesForCategory(categoryName);

      if (mounted) {
        setState(() {
          allTemplates = templates;
          filteredTemplates = templates;
          selectedTemplateIds.clear();
          _searchController.clear();

          templateRecipeStatus.clear();
          for (var controller in templatePriceControllers.values) {
            controller.dispose();
          }
          templatePriceControllers.clear();

          for (var config in templateVariantConfigs.values) {
            config.dispose();
          }
          templateVariantConfigs.clear();

          for (var template in templates) {
            final templateId = template['id'] as int;
            final templateName = template['name'] as String? ?? 'İsimsiz Ürün';

            templateRecipeStatus[templateId] = true;
            // ✅ FİX: Price controller'a listener ekliyoruz
            final priceController = TextEditingController();
            priceController.addListener(() {
              // Fiyat değiştiğinde setState çağır
              if (mounted) {
                setState(() {
                  // Bu setState çağrısı _isButtonEnabled'ı yeniden hesaplar
                });
              }
            });
            templatePriceControllers[templateId] = priceController;
            
            templateVariantConfigs[templateId] = VariantTemplateConfig(
              templateId: templateId,
              templateName: templateName,
            );
          }
        });

        _loadVariantTemplatesForCategory(categoryName);
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

  Future<void> _loadVariantTemplatesForCategory(String categoryName) async {
    if (!mounted) return;
    setState(() => _isLoadingVariantTemplates = true);

    try {
      final variantTemplates = await _service.fetchVariantTemplatesForCategory(categoryName);

      if (mounted) {
        setState(() {
          _variantTemplates = variantTemplates;
        });
      }
    } catch (e) {
      try {
        final defaultTemplates = await _service.fetchDefaultVariantTemplates();
        if (mounted) {
          setState(() {
            _variantTemplates = defaultTemplates.take(8).toList();
          });
        }
      } catch (e2) {
        if (mounted) {
          setState(() {
            _variantTemplates = [];
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingVariantTemplates = false);
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

  void _toggleRecipeStatus(int templateId) {
    setState(() {
      templateRecipeStatus[templateId] = !(templateRecipeStatus[templateId] ?? true);

      if (templateRecipeStatus[templateId] == true) {
        templatePriceControllers[templateId]?.clear();
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

  bool _validatePrices() {
    for (int templateId in selectedTemplateIds) {
      final isFromRecipe = templateRecipeStatus[templateId] ?? true;
      if (!isFromRecipe) {
        final priceText = templatePriceControllers[templateId]?.text.trim() ?? '';
        if (priceText.isEmpty) {
          return false;
        }
        final price = double.tryParse(priceText.replaceAll(',', '.'));
        if (price == null || price < 0) {
          return false;
        }
      }
    }
    return true;
  }

  bool _validateVariantImages() {
    for (int templateId in selectedTemplateIds) {
      final variantConfig = templateVariantConfigs[templateId];
      if (variantConfig != null && variantConfig.hasVariantImageEnabled) {
        if (variantConfig.variants.isNotEmpty) {
          bool hasValidVariant = variantConfig.variants.any((variant) => variant.image.isNotEmpty);
          if (!hasValidVariant) {
            return false;
          }
        }
      }
    }
    return true;
  }
  
  // ✅ GÜNCELLEME: Manuel seçim yapılan ürünler için varyant zorunluluğu kontrolü yapılmayacak
  bool _validateAllSelectedItemsHaveVariants() {
    if (selectedTemplateIds.isEmpty) {
      return true; 
    }
    return selectedTemplateIds.every((id) {
      final isFromRecipe = templateRecipeStatus[id] ?? true;
      
      // ✅ YENİ KONTROL: Eğer manuel seçim yapılmışsa (isFromRecipe = false) varyant zorunlu değil
      if (!isFromRecipe) {
        return true; // Manuel seçimde varyant zorunlu değil
      }
      
      // Reçeteli ürünlerde varyant zorunlu
      final config = templateVariantConfigs[id];
      return config != null && config.variants.isNotEmpty;
    });
  }

  Future<void> _openVariantManagementDialog(int templateId) async {
    final variantConfig = templateVariantConfigs[templateId];
    if (variantConfig == null) return;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VariantManagementDialog(
        templateId: templateId,
        variantConfig: variantConfig,
        variantTemplates: _variantTemplates,
        isLoadingVariantTemplates: _isLoadingVariantTemplates,
        businessId: widget.businessId,
        onVariantTemplateSelected: (variantTemplate) {
          _addQuickVariant(templateId, variantTemplate);
        },
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _addQuickVariant(int templateId, Map<String, dynamic> variantTemplate) {
    final variantConfig = templateVariantConfigs[templateId];
    if (variantConfig == null) return;

    final variantName = variantTemplate['name'] as String;

    if (variantConfig.variants.any((v) => v.name.toLowerCase() == variantName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$variantName varyantı zaten eklenmiş'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    double multiplier = 1.0;
    try {
      final multiplierValue = variantTemplate['price_multiplier'];
      if (multiplierValue != null) {
        if (multiplierValue is String) {
          multiplier = double.tryParse(multiplierValue) ?? 1.0;
        } else if (multiplierValue is num) {
          multiplier = multiplierValue.toDouble();
        }
      }
    } catch (e) {
      debugPrint('Price multiplier conversion error: $e');
      multiplier = 1.0;
    }

    final basePrice = 25.0;
    final calculatedPrice = basePrice * multiplier;

    bool isExtra = false;
    try {
      final isExtraValue = variantTemplate['is_extra'];
      if (isExtraValue != null) {
        if (isExtraValue is bool) {
          isExtra = isExtraValue;
        } else if (isExtraValue is String) {
          isExtra = isExtraValue.toLowerCase() == 'true';
        } else if (isExtraValue is num) {
          isExtra = isExtraValue != 0;
        }
      }
    } catch (e) {
      debugPrint('is_extra conversion error: $e');
      isExtra = false;
    }

    setState(() {
      variantConfig.variantNameController.text = variantName;
      variantConfig.variantPriceController.text = calculatedPrice.toStringAsFixed(2);
      variantConfig.isVariantExtra = isExtra;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$variantName bilgileri forma eklendi - düzenleyip ekleyebilirsiniz'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onCustomProductAdded(Map<String, dynamic> customProductData) {
    final int customTemplateId = customProductData['templateId'];
    final String productName = customProductData['productName'];
    final bool isFromRecipe = customProductData['isFromRecipe'];
    final double? price = customProductData['price'];
    final List<dynamic> variants = customProductData['variants'] ?? [];

    setState(() {
      selectedTemplateIds.add(customTemplateId);
      templateRecipeStatus[customTemplateId] = isFromRecipe;
      
      // ✅ FİX: Custom product için de price controller'a listener ekliyoruz
      final priceController = TextEditingController();
      priceController.addListener(() {
        if (mounted) {
          setState(() {
            // Bu setState çağrısı _isButtonEnabled'ı yeniden hesaplar
          });
        }
      });
      
      if (!isFromRecipe && price != null) {
        priceController.text = price.toStringAsFixed(2);
      }
      templatePriceControllers[customTemplateId] = priceController;
      
      final variantConfig = VariantTemplateConfig(
        templateId: customTemplateId,
        templateName: productName,
      );

      for (var variantData in variants) {
        final variant = MenuItemVariant(
          id: -DateTime.now().millisecondsSinceEpoch,
          menuItem: 0,
          name: variantData['name'] ?? '',
          price: (variantData['price'] ?? 0.0).toDouble(),
          isExtra: variantData['isExtra'] ?? false,
          image: variantData['image'] ?? '',
        );
        variantConfig.addVariant(variant);
      }

      templateVariantConfigs[customTemplateId] = variantConfig;
      allTemplates.insert(0, {
        'id': customTemplateId,
        'name': productName,
        'isCustomProduct': true,
      });

      _filterTemplates();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNewlyAddedItem(customTemplateId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Özel ürün "$productName" eklendi ve seçildi'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'GÖSTER',
          textColor: Colors.white,
          onPressed: () => _scrollToNewlyAddedItem(customTemplateId),
        ),
      ),
    );
  }

  void _scrollToNewlyAddedItem(int templateId) {
    try {
      final itemIndex = filteredTemplates.indexWhere((template) => template['id'] == templateId);

      if (itemIndex != -1 && _scrollController.hasClients) {
        const double itemHeight = 80.0;
        const double headerHeight = 200.0;

        final double targetOffset = headerHeight + (itemIndex * itemHeight);
        final double maxScrollExtent = _scrollController.position.maxScrollExtent;
        final double safeOffset = targetOffset > maxScrollExtent ? maxScrollExtent : targetOffset;

        _scrollController.animateTo(
          safeOffset,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (_scrollController.hasClients && mounted) {
            _scrollController.animateTo(
              safeOffset,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      print('❌ Error scrolling to newly added item: $e');
    }
  }

  void _ensureSelectedItemVisible(int templateId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNewlyAddedItem(templateId);
    });
  }

  Map<String, dynamic> _prepareResultData() {
    final List<int> templateIds = selectedTemplateIds.toList();
    final List<Map<String, dynamic>> templatesWithOptions = [];

    for (int templateId in selectedTemplateIds) {
      final isFromRecipe = templateRecipeStatus[templateId] ?? true;
      final priceText = templatePriceControllers[templateId]?.text.trim() ?? '';
      final variantConfig = templateVariantConfigs[templateId];
      final variantList = variantConfig?.variants.map((v) {
        return {
          'name': v.name,
          'price': v.price,
          'isExtra': v.isExtra,
          'image': v.image,
        };
      }).toList() ?? [];

      final template = allTemplates.firstWhere(
        (t) => t['id'] == templateId,
        orElse: () => {'id': templateId, 'name': 'Unknown', 'isCustomProduct': false},
      );

      templatesWithOptions.add({
        'templateId': templateId,
        'isFromRecipe': isFromRecipe,
        'price': isFromRecipe ? null : double.tryParse(priceText.replaceAll(',', '.')),
        'variants': variantList,
        'hasVariantImage': variantConfig?.hasVariantImage ?? false,
        'variantImageEnabled': variantConfig?.hasVariantImageEnabled ?? false,
        'variantImageData': null,
        'isCustomProduct': template['isCustomProduct'] ?? false,
        'productName': template['isCustomProduct'] == true ? template['name'] : null,
      });
    }

    return {
      'selectedTemplateIds': templateIds,
      'targetCategoryId': _targetCategoryId,
      'count': selectedTemplateIds.length,
      'selectedTemplates': templatesWithOptions,
    };
  }

  // ✅ GÜNCELLEME: Butonun aktif olma koşulu güncellendi - manuel seçimlerde varyant zorunluluğu kaldırıldı
  bool get _isButtonEnabled {
    final hasSelection = selectedTemplateIds.isNotEmpty;
    if (!hasSelection) return false;

    final hasCategory = _targetCategoryId != null;
    final pricesValid = _validatePrices();
    final imageVariantsValid = _validateVariantImages();
    
    // ✅ YENİ KONTROL: Manuel seçimler için varyant zorunluluğu kaldırıldı
    final allSelectedHaveVariants = _validateAllSelectedItemsHaveVariants();

    return hasCategory && pricesValid && imageVariantsValid && allSelectedHaveVariants;
  }

  void _onCategoryChanged(String? categoryName) {
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
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    
    final availableHeight = screenHeight - keyboardHeight - 100.0;
    final dialogHeight = availableHeight > 400.0 ? availableHeight : 400.0;
    
    // ✅ GÜNCELLEME: Varyant zorunluluğu için hata mesajı kontrolü - manuel seçimleri hariç tutuyor
    final bool everySelectedHasVariant = _validateAllSelectedItemsHaveVariants();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? screenWidth * 0.1 : 16.0,
        vertical: keyboardHeight > 0 ? 20.0 : 40.0,
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.addProductFromTemplateTitle,
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
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                    ],
                  ),
                  
                  // ✅ YENİ: Hata mesajını header'ın altına ekliyoruz
                  if (!_isButtonEnabled && selectedTemplateIds.isNotEmpty && !everySelectedHasVariant)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.red.shade200,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.templateVariantRequiredError,
                              style: TextStyle(
                                color: Colors.red.shade200,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Content with glass effect
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15), // ✅ Daha az şeffaflık
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3), // ✅ Daha opak border
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TemplateSelectionContent(
                  currentMenuItemCount: widget.currentMenuItemCount,
                  selectedTemplateIds: selectedTemplateIds,
                  templateVariantConfigs: templateVariantConfigs,
                  availableCategories: widget.availableCategories,
                  selectedCategoryName: _selectedCategoryName,
                  searchController: _searchController,
                  isLoadingTemplates: _isLoadingTemplates,
                  allTemplates: allTemplates,
                  filteredTemplates: filteredTemplates,
                  templateRecipeStatus: templateRecipeStatus,
                  templatePriceControllers: templatePriceControllers,
                  targetCategoryId: _targetCategoryId,
                  businessId: widget.businessId,
                  token: widget.token,
                  scrollController: _scrollController,
                  onCategoryChanged: _onCategoryChanged,
                  onToggleSelectAll: _toggleSelectAll,
                  onToggleTemplateSelection: _toggleTemplateSelection,
                  onToggleRecipeStatus: _toggleRecipeStatus,
                  onOpenVariantManagement: _openVariantManagementDialog,
                  onShowLimitReached: _showLimitReachedDialog,
                  onCustomProductAdded: _onCustomProductAdded,
                ),
              ),
            ),
            
            // ✅ FİX: Footer'ı dinamik yükseklik ile güncelledik
            Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    
                    // ✅ Küçük ekranlar için farklı düzen - dinamik yükseklik ile
                    if (availableWidth < 350) {
                      return IntrinsicHeight(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // İlk satır: Yeni Ürün Ekle butonu
                            if (_targetCategoryId != null)
                              Container(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await showDialog<Map<String, dynamic>>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => CustomProductDialog(
                                        token: widget.token,
                                        businessId: widget.businessId,
                                        targetCategoryId: _targetCategoryId!,
                                        selectedCategoryName: _selectedCategoryName ?? '',
                                      ),
                                    );

                                    if (result != null) {
                                      _onCustomProductAdded(result);
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 14),
                                  label: Text(
                                    'Yeni Ürün',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            
                            const SizedBox(height: 8), // Araya boşluk
                            
                            // İkinci satır: İptal ve Ekle butonları
                            SizedBox(
                              height: 36,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white.withOpacity(0.9),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                        ),
                                      ),
                                      child: Text(
                                        l10n.dialogButtonCancel,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _isButtonEnabled ? () {
                                        if (!_validateVariantImages()) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Varyant fotoğrafları eksik. Lütfen kontrol edin.'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        final result = _prepareResultData();
                                        Navigator.of(context).pop(result);
                                      } : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.blue.shade700,
                                        disabledBackgroundColor: Colors.white.withOpacity(0.3),
                                        disabledForegroundColor: Colors.white.withOpacity(0.5),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 4,
                                      ),
                                      child: Text(
                                        'Ekle',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    // ✅ Normal ekranlar için tek satır düzen - sabit yükseklik
                    return SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          // Yeni Ürün Ekle butonu (sol taraf)
                          if (_targetCategoryId != null)
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => CustomProductDialog(
                                      token: widget.token,
                                      businessId: widget.businessId,
                                      targetCategoryId: _targetCategoryId!,
                                      selectedCategoryName: _selectedCategoryName ?? '',
                                    ),
                                  );

                                  if (result != null) {
                                    _onCustomProductAdded(result);
                                  }
                                },
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: Text(
                                  l10n.addNewProduct,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 2,
                                ),
                              ),
                            ),
                          
                          const Spacer(), // Orta boşluk
                          
                          // İptal butonu
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white.withOpacity(0.9),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                              ),
                            ),
                            child: Text(
                              l10n.dialogButtonCancel,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Seçilenleri Ekle butonu
                          ElevatedButton(
                            onPressed: _isButtonEnabled ? () {
                              if (!_validateVariantImages()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Varyant fotoğrafları eksik. Lütfen kontrol edin.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final result = _prepareResultData();
                              Navigator.of(context).pop(result);
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue.shade700,
                              disabledBackgroundColor: Colors.white.withOpacity(0.3),
                              disabledForegroundColor: Colors.white.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: Text(
                              l10n.templateAddSelectedButton,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
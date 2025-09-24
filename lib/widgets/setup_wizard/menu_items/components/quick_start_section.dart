// lib/widgets/setup_wizard/menu_items/components/quick_start_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../services/user_session.dart';
import '../../../../services/firebase_storage_service.dart';
import '../../../../models/menu_item_variant.dart';
import '../services/menu_item_service.dart';
import '../dialogs/template_selection_dialog.dart';
import '../dialogs/limit_reached_dialog.dart';
import '../utils/newly_added_tracker.dart'; // ✅ YENİ IMPORT
import 'dart:io';
import 'package:path/path.dart' as p;

class QuickStartSection extends StatefulWidget {
  final String token;
  final List<dynamic> availableCategories;
  final int currentMenuItemCount;
  final VoidCallback onMenuItemsAdded;
  final Function(String, {bool isError}) onMessageChanged;
  final int businessId;

  const QuickStartSection({
    Key? key,
    required this.token,
    required this.availableCategories,
    required this.currentMenuItemCount,
    required this.onMenuItemsAdded,
    required this.onMessageChanged,
    required this.businessId,
  }) : super(key: key);

  @override
  State<QuickStartSection> createState() => _QuickStartSectionState();
}

class _QuickStartSectionState extends State<QuickStartSection> {
  final MenuItemService _menuItemService = MenuItemService();
  bool _isAddingFromTemplates = false;

  Future<void> _openTemplateSelectionDialog() async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.availableCategories.isEmpty) {
      widget.onMessageChanged(
        l10n.setupMenuItemsErrorCreateCategoryFirst,
        isError: true,
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectionDialog(
        token: widget.token,
        availableCategories: widget.availableCategories,
        currentMenuItemCount: widget.currentMenuItemCount,
        businessId: widget.businessId,
      ),
    );

    if (result != null && mounted) {
      await _handleTemplateSelectionResult(result);
    }
  }

  Future<void> _handleTemplateSelectionResult(Map<String, dynamic> result) async {
    // YENİ FORMAT: selectedTemplates varsa onu kullan
    if (result.containsKey('selectedTemplates')) {
      final List<dynamic> selectedTemplates = result['selectedTemplates'];
      final int targetCategoryId = result['targetCategoryId'];
      
      await _createMenuItemsFromTemplatesAdvanced(
        selectedTemplates.cast<Map<String, dynamic>>(),
        targetCategoryId,
      );
      return;
    }
    
    // ESKİ FORMAT: Geriye uyumluluk için
    final List<int> templateIds = (result['selectedTemplateIds'] as List<dynamic>).cast<int>();
    final int targetCategoryId = result['targetCategoryId'];
    
    await _createMenuItemsFromTemplatesLegacy(templateIds, targetCategoryId);
  }

  Future<void> _createMenuItemsFromTemplatesAdvanced(
    List<Map<String, dynamic>> selectedTemplates,
    int targetCategoryId,
  ) async {
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context)!;
    final currentLimits = UserSession.limitsNotifier.value;
    
    if (widget.currentMenuItemCount + selectedTemplates.length > currentLimits.maxMenuItems) {
      showDialog(
        context: context,
        builder: (ctx) => LimitReachedDialog(
          title: l10n.dialogLimitReachedTitle,
          message: l10n.createMenuItemErrorLimitExceeded(currentLimits.maxMenuItems.toString()),
        ),
      );
      return;
    }

    setState(() => _isAddingFromTemplates = true);

    try {
      int successCount = 0;
      final int businessId = widget.businessId;
      
      // ✅ GÜNCELLENME: NewlyAddedTracker kullan
      final menuItemsBefore = await _menuItemService.fetchInitialData(widget.token);
      final existingItemIds = (menuItemsBefore['menuItems'] as List)
          .map((item) => item['id'] as int)
          .toSet();
      
      if (kDebugMode) {
        print('🏢 BusinessId bulundu: $businessId');
        print('📋 Mevcut ürün sayısı: ${existingItemIds.length}');
      }
      
      for (var templateData in selectedTemplates) {
        final int templateId = templateData['templateId'];
        final bool isFromRecipe = templateData['isFromRecipe'] ?? true;
        final double? price = templateData['price'];
        final List<dynamic> variantData = templateData['variants'] ?? [];
        final bool isCustomProduct = templateData['isCustomProduct'] ?? false;
        final String? productName = templateData['productName'];
        
        if (kDebugMode) {
          print('📦 Processing ${isCustomProduct ? "Custom Product" : "Template"} ${isCustomProduct ? productName : templateId}:');
          print('  - Is Custom: $isCustomProduct');
          print('  - Variant count: ${variantData.length}');
          for (var variant in variantData) {
            print('    * ${variant['name']}: imageUrl=${variant['image']}');
          }
        }
        
        // Varyantları hazırla
        List<MenuItemVariant> variants = [];
        for (var i = 0; i < variantData.length; i++) {
          final v = variantData[i];
          variants.add(MenuItemVariant(
            id: -DateTime.now().millisecondsSinceEpoch - i,
            menuItem: 0,
            name: v['name'] ?? '',
            price: (v['price'] ?? 0.0).toDouble(),
            isExtra: v['isExtra'] ?? false,
            image: v['image'] ?? '',
          ));
        }
        
        try {
          if (isCustomProduct && productName != null) {
            // Özel ürün oluştur
            await _createCustomMenuItem(
              productName: productName,
              targetCategoryId: targetCategoryId,
              isFromRecipe: isFromRecipe,
              price: price,
              businessId: businessId,
              variants: variants.isNotEmpty ? variants : null,
            );
          } else {
            // Normal template ürün oluştur
            await _menuItemService.createMenuItemFromTemplateAdvanced(
              token: widget.token,
              templateId: templateId,
              targetCategoryId: targetCategoryId,
              isFromRecipe: isFromRecipe,
              price: price,
              businessId: businessId,
              variants: variants.isNotEmpty ? variants : null,
              l10n: l10n, // HATA GİDERİLDİ: l10n parametresi eklendi
            );
          }
          successCount++;
        } catch (e) {
          // Tek ürün hatası tüm işlemi durdurmasın
          if (kDebugMode) {
            print('${isCustomProduct ? "Custom product" : "Template"} ${isCustomProduct ? productName : templateId} için hata: $e');
          }
          continue;
        }
      }

      // ✅ GÜNCELLENME: NewlyAddedTracker kullan
      if (successCount > 0) {
        await _markNewlyAddedItems(existingItemIds);
      }

      if (mounted) {
        if (successCount > 0) {
          widget.onMessageChanged(
            l10n.menuItemsAddedSuccess(successCount),
          );
          widget.onMenuItemsAdded();
        } else {
          widget.onMessageChanged(
            l10n.menuItemsAddedError,
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        widget.onMessageChanged(
          l10n.errorUploadingPhotoGeneral(e.toString().replaceFirst("Exception: ", "")),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingFromTemplates = false);
    }
  }

  // ✅ GÜNCELLENME: NewlyAddedTracker kullan ve debug logları iyileştirildi
  Future<void> _markNewlyAddedItems(Set<int> existingItemIds) async {
    try {
      // Güncel ürün listesini al
      final menuItemsAfter = await _menuItemService.fetchInitialData(widget.token);
      final currentItems = menuItemsAfter['menuItems'] as List;
      
      // Yeni eklenen ürünleri tespit et
      final newItemIds = <int>{};
      for (var item in currentItems) {
        final itemId = item['id'] as int;
        if (!existingItemIds.contains(itemId)) {
          newItemIds.add(itemId);
          
          if (kDebugMode) {
            print('🆕 Yeni ürün işaretlendi: ${item['name']} (ID: $itemId)');
          }
        }
      }
      
      // Yeni ürünleri tracker'a ekle
      if (newItemIds.isNotEmpty) {
        NewlyAddedTracker.markAsNewlyAdded(newItemIds);
        
        if (kDebugMode) {
          print('🔥 NewlyAddedTracker güncellendi. Yeni ürünler: $newItemIds');
          print('🔥 Tracker durumu: ${NewlyAddedTracker.newlyAddedItems}');
        }
        
        // ✅ YENİ: UI'ı hemen güncelle
        if (mounted) {
          widget.onMenuItemsAdded();
          
          // 1 saniye sonra da bir kez daha güncelle (emin olmak için)
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              widget.onMenuItemsAdded();
            }
          });
        }
        
        // UI güncelleme için callback tetikle
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            widget.onMenuItemsAdded();
          }
        });
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Yeni ürünleri işaretlerken hata: $e');
      }
    }
  }

  Future<void> _createCustomMenuItem({
    required String productName,
    required int targetCategoryId,
    required bool isFromRecipe,
    required double? price,
    required int businessId,
    required List<MenuItemVariant>? variants,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (kDebugMode) {
        print('🆕 Creating custom menu item:');
        print('  - Name: $productName');
        print('  - Category ID: $targetCategoryId');
        print('  - Is Recipe: $isFromRecipe');
        print('  - Price: $price');
        print('  - Business ID: $businessId');
        print('  - Variants: ${variants?.length ?? 0}');
      }

      // Özel ürün için createMenuItemCustom metodu çağır
      await _menuItemService.createMenuItemCustom(
        token: widget.token,
        name: productName,
        targetCategoryId: targetCategoryId,
        isFromRecipe: isFromRecipe,
        price: price,
        businessId: businessId,
        variants: variants,
        l10n: l10n, // HATA GİDERİLDİ: l10n parametresi eklendi
      );

      if (kDebugMode) {
        print('✅ Custom menu item "$productName" created successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Custom menu item creation error: $e');
      }
      throw Exception(l10n.errorCreatingCustomProduct(e.toString()));
    }
  }

  Future<void> _createMenuItemsFromTemplatesLegacy(
    List<int> templateIds, 
    int targetCategoryId,
  ) async {
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context)!;
    final currentLimits = UserSession.limitsNotifier.value;
    
    if (widget.currentMenuItemCount + templateIds.length > currentLimits.maxMenuItems) {
      showDialog(
        context: context,
        builder: (ctx) => LimitReachedDialog(
          title: l10n.dialogLimitReachedTitle,
          message: l10n.createMenuItemErrorLimitExceeded(currentLimits.maxMenuItems.toString()),
        ),
      );
      return;
    }

    setState(() => _isAddingFromTemplates = true);

    try {
      // ✅ GÜNCELLENME: Legacy için de NewlyAddedTracker kullan
      final menuItemsBefore = await _menuItemService.fetchInitialData(widget.token);
      final existingItemIds = (menuItemsBefore['menuItems'] as List)
          .map((item) => item['id'] as int)
          .toSet();

      final createdItems = await _menuItemService.createMenuItemsFromTemplates(
        token: widget.token,
        templateIds: templateIds,
        targetCategoryId: targetCategoryId,
      );

      if (createdItems.isNotEmpty) {
        await _markNewlyAddedItems(existingItemIds);
      }

      if (mounted) {
        widget.onMessageChanged(
          l10n.menuItemsAddedSuccess(createdItems.length),
        );
        widget.onMenuItemsAdded();
      }
    } catch (e) {
      if (mounted) {
        widget.onMessageChanged(
          l10n.errorUploadingPhotoGeneral(e.toString().replaceFirst("Exception: ", "")),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingFromTemplates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        // ✅ GÜNCELLENME: Kategoriler sayfasındaki gibi gradient arka plan
        gradient: LinearGradient(
          colors: [Colors.green.withOpacity(0.7), Colors.green.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // ✅ GÜNCELLENME: Kategoriler sayfasındaki gibi büyük merkezi icon
          Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          // ✅ GÜNCELLENME: Kategoriler sayfasındaki gibi büyük başlık
          Text(
            l10n.quickStartTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // ✅ GÜNCELLENME: Kategoriler sayfasındaki gibi açıklama metni
          Text(
            l10n.quickStartDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          // ✅ GÜNCELLENME: Kategoriler sayfasındaki gibi beyaz buton tasarımı
          ElevatedButton.icon(
            icon: _isAddingFromTemplates
                ? const SizedBox.shrink()
                : const Icon(Icons.auto_awesome),
            label: _isAddingFromTemplates
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: Colors.green.shade700
                        )
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.addFromTemplateButton),
                    ],
                  )
                : Text(l10n.addFromTemplateButton),
            onPressed: _isAddingFromTemplates || widget.availableCategories.isEmpty
                ? null
                : _openTemplateSelectionDialog,
            style: ElevatedButton.styleFrom(
              // ✅ GÜNCELLENME: Kategoriler sayfasındaki gibi beyaz arka plan
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              // ✅ GÜNCELLENME: Kategoriler sayfasındaki gibi minimum boy
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}
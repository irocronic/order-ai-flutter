// lib/controllers/add_order_item_dialog_controller.dart

import 'package:flutter/material.dart'; // Sadece ChangeNotifier için (opsiyonel)
import 'package:collection/collection.dart';
import '../models/menu_item.dart';
import '../models/menu_item_variant.dart';

/// AddOrderItemDialog'un state'ini ve iş mantığını yönetir.
/// ChangeNotifier KULLANILABİLİR ama şimdilik callback ile devam edelim.
class AddOrderItemDialogController {
  // --- Dependencies & Callbacks ---
  final List<MenuItem> allMenuItems;
  final List<dynamic> categories;
  final List<String> tableUsers;
  final Function() onStateUpdate; // UI güncelleme callback'i

  // --- Internal State ---
  dynamic _selectedTopCategory;
  dynamic _selectedSubCategory;
  MenuItem? _selectedItem; // Başlangıçta null olabilir
  MenuItemVariant? _selectedNormalVariant;
  List<MenuItemVariant> _selectedExtraVariants = [];
  String? _selectedTableUser;

  // --- Derived State (Getters) ---
  dynamic get selectedTopCategory => _selectedTopCategory;
  dynamic get selectedSubCategory => _selectedSubCategory;
  MenuItem? get selectedItem => _selectedItem;
  MenuItemVariant? get selectedNormalVariant => _selectedNormalVariant;
  List<MenuItemVariant> get selectedExtraVariants => _selectedExtraVariants;
  String? get selectedTableUser => _selectedTableUser;

  // Filtrelenmiş ve hesaplanmış listeler
  List<dynamic> get topCategories => _getTopCategories();
  List<dynamic> get subCategories => _getSubCategories();
  List<MenuItem> get filteredMenuItems => _getFilteredMenuItems();
  List<MenuItemVariant> normalVariants = []; // Seçili ürüne göre güncellenir
  List<MenuItemVariant> extraVariants = []; // Seçili ürüne göre güncellenir

  AddOrderItemDialogController({
    required this.allMenuItems,
    required this.categories,
    required this.tableUsers,
    required this.onStateUpdate,
  }) {
    _initializeSelection();
    if (tableUsers.isNotEmpty) {
      _selectedTableUser = tableUsers.first;
    }
  }

  // --- Initialization Logic ---

  void _initializeSelection() {
    List<MenuItem> initialFilteredItems = _getFilteredMenuItems();
    if (initialFilteredItems.isNotEmpty) {
      _selectedItem = initialFilteredItems.first;
    } else if (allMenuItems.isNotEmpty) {
      _selectedItem = allMenuItems.first;
    } else {
      _selectedItem = null; // Menü boşsa seçili ürün yok
    }
    _updateVariantsForSelectedItem();
  }

  void _updateVariantsForSelectedItem() {
    if (_selectedItem?.variants != null) {
      normalVariants = _selectedItem!.variants!.where((v) => !v.isExtra).toList();
      extraVariants = _selectedItem!.variants!.where((v) => v.isExtra).toList();
    } else {
      normalVariants = [];
      extraVariants = [];
    }
    _selectedNormalVariant = normalVariants.isNotEmpty ? normalVariants.first : null;
    _selectedExtraVariants = []; // Ürün değişince ekstraları sıfırla
    onStateUpdate(); // State değişti, UI'ı güncelle
  }

  // --- Category Logic ---

  List<dynamic> _getTopCategories() {
    List<dynamic> result = [{'id': null, 'name': 'Tümü', 'parent': null}];
    result.addAll(categories.where((cat) => cat['parent'] == null).toList());
    return result;
  }

  List<dynamic> _getSubCategories() {
    if (_selectedTopCategory == null || _selectedTopCategory['id'] == null) return [];
    List<dynamic> result = [{'id': _selectedTopCategory['id'], 'name': 'Tümü', 'parent': _selectedTopCategory['id']}];
    result.addAll(categories.where((cat) => cat['parent'] == _selectedTopCategory['id']).toList());
    return result;
  }

  void selectTopCategory(dynamic category) {
    _selectedTopCategory = category?['id'] == null ? null : category;
    _selectedSubCategory = null; // Alt kategori seçimini sıfırla
    // Filtrelenmiş ürünleri güncelle ve ilkini seç
    _updateFilteredItemsAndSelection();
    onStateUpdate();
  }

  void selectSubCategory(dynamic category) {
    _selectedSubCategory = category;
    // Filtrelenmiş ürünleri güncelle ve ilkini seç
    _updateFilteredItemsAndSelection();
    onStateUpdate();
  }

  // --- Menu Item Logic ---

  List<MenuItem> _getFilteredMenuItems() {
    if (_selectedTopCategory == null || _selectedTopCategory['id'] == null) {
      return allMenuItems;
    }

    if (_selectedSubCategory != null && _selectedSubCategory['id'] != _selectedTopCategory['id']) {
      return allMenuItems.where((item) => item.category?['id'] == _selectedSubCategory['id']).toList();
    } else {
      List<int?> relevantCategoryIds = [_selectedTopCategory['id']];
      relevantCategoryIds.addAll(categories
          .where((cat) => cat['parent'] == _selectedTopCategory['id'])
          .map<int?>((cat) => cat['id'])
          .whereNotNull()
          .toList());
      return allMenuItems.where((item) => relevantCategoryIds.contains(item.category?['id'])).toList();
    }
  }

  void _updateFilteredItemsAndSelection() {
     List<MenuItem> currentFiltered = _getFilteredMenuItems();
     if (currentFiltered.isNotEmpty) {
        // Eğer mevcut seçili ürün yeni filtrede yoksa veya hiç seçili ürün yoksa, ilki seç
        if (_selectedItem == null || !currentFiltered.any((item) => item.id == _selectedItem!.id)){
           _selectedItem = currentFiltered.first;
        }
     } else {
       // Filtre sonucu ürün yoksa seçimi kaldır
        _selectedItem = null;
     }
      _updateVariantsForSelectedItem(); // Seçili ürüne (veya null'a) göre varyantları güncelle
  }


  void selectItem(MenuItem item) {
    _selectedItem = item;
    _updateVariantsForSelectedItem(); // Varyantları ve ekstraları güncelle/sıfırla
    onStateUpdate();
  }

  // --- Variant & Extra Logic ---

  void selectNormalVariant(MenuItemVariant? variant) {
    _selectedNormalVariant = variant;
    onStateUpdate();
  }

  void toggleExtraVariant(MenuItemVariant variant) {
    if (_selectedExtraVariants.contains(variant)) {
      _selectedExtraVariants.remove(variant);
    } else {
      _selectedExtraVariants.add(variant);
    }
    onStateUpdate();
  }

  // --- Table User Logic ---

  void selectTableUser(String? user) {
    _selectedTableUser = user;
    onStateUpdate();
  }

  // --- Get Final Selection ---
  // 'Ekle' butonuna basıldığında çağrılacak
  Map<String, dynamic>? getFinalSelection() {
    if (_selectedItem == null) {
       print("Hata: Ürün seçilmedi."); // Ya da snackbar göster
       return null;
    }
     if (normalVariants.isNotEmpty && _selectedNormalVariant == null) {
       print("Hata: Normal varyant seçilmedi."); // Ya da snackbar göster
       return null;
    }
     if (tableUsers.isNotEmpty && _selectedTableUser == null) {
       print("Hata: Masa sahibi seçilmedi."); // Ya da snackbar göster
       return null;
    }

    return {
      'item': _selectedItem!,
      'variant': _selectedNormalVariant,
      'extras': List<MenuItemVariant>.from(_selectedExtraVariants), // Kopyasını gönder
      'tableUser': _selectedTableUser,
    };
  }
}
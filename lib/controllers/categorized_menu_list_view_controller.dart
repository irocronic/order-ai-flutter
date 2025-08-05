//lib/controllers/categorized_menu_list_view_controller.dart

import 'package:flutter/material.dart'; // Sadece ChangeNotifier için (opsiyonel)
import 'package:collection/collection.dart';
import '../models/menu_item.dart';

/// CategorizedMenuListView'ın state'ini ve filtreleme mantığını yönetir.
class CategorizedMenuListViewController {
  // --- Dependencies & Callbacks ---
  final List<MenuItem> allMenuItems;
  final List<dynamic> allCategories;
  final Function() onStateUpdate; // UI güncelleme callback'i

  // --- Internal State ---
  dynamic _selectedTopCategory;
  dynamic _selectedSubCategory;

  // --- Getters for State ---
  dynamic get selectedTopCategory => _selectedTopCategory;
  dynamic get selectedSubCategory => _selectedSubCategory;

  // --- Derived State (Getters) ---
  List<dynamic> get topCategories => _getTopCategories();
  List<dynamic> get subCategories => _getSubCategories();
  List<MenuItem> get filteredMenuItems => _getFilteredMenuItems();

  CategorizedMenuListViewController({
    required this.allMenuItems,
    required this.allCategories,
    required this.onStateUpdate,
  });

  // --- Category Logic ---

  List<dynamic> _getTopCategories() {
    List<dynamic> result = [{'id': null, 'name': 'Tümü', 'parent': null}];
    result.addAll(allCategories.where((cat) => cat['parent'] == null).toList());
    return result;
  }

  List<dynamic> _getSubCategories() {
    if (_selectedTopCategory == null || _selectedTopCategory['id'] == null) return [];
    List<dynamic> result = [{'id': _selectedTopCategory['id'], 'name': 'Tümü', 'parent': _selectedTopCategory['id']}];
    result.addAll(allCategories.where((cat) => cat['parent'] == _selectedTopCategory['id']).toList());
    return result;
  }

  void selectTopCategory(dynamic category) {
    _selectedTopCategory = category?['id'] == null ? null : category;
    _selectedSubCategory = null; // Alt kategori seçimini sıfırla
    onStateUpdate(); // State değişti, UI'ı güncelle
  }

  void selectSubCategory(dynamic category) {
    _selectedSubCategory = category;
    onStateUpdate(); // State değişti, UI'ı güncelle
  }

  // --- Menu Item Filtering Logic ---

  List<MenuItem> _getFilteredMenuItems() {
    if (_selectedTopCategory == null || _selectedTopCategory['id'] == null) {
      return allMenuItems;
    }

    if (_selectedSubCategory != null && _selectedSubCategory['id'] != _selectedTopCategory['id']) {
       // Alt kategoriye göre filtrele
       return allMenuItems.where((item) {
         final cat = item.category;
         if (cat == null || !(cat is Map) || cat['id'] == null || !(cat['id'] is int) ) return false;
         return cat['id'] == _selectedSubCategory['id'];
       }).toList();
    } else {
      // Üst kategori ve onun alt kategorilerine göre filtrele
       List<int?> relevantCategoryIds = [_selectedTopCategory['id']];
       relevantCategoryIds.addAll(allCategories
          .where((cat) => cat['parent'] == _selectedTopCategory['id'])
          .map<int?>((cat) => cat['id'])
          .whereNotNull()
          .toList());

       return allMenuItems.where((item) {
          final cat = item.category;
          if (cat == null || !(cat is Map) || cat['id'] == null || !(cat['id'] is int) ) return false;
          return relevantCategoryIds.contains(cat['id']);
       }).toList();
     }
  }
}



// lib/widgets/setup_wizard/menu_items/services/menu_item_service.dart
import 'dart:convert';
import '../../../../services/api_service.dart';
import '../../../../services/firebase_storage_service.dart';
import '../../../../models/menu_item.dart';
import '../models/menu_item_form_data.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class MenuItemService {
  // 🔧 DÜZELTİLDİ: MenuItem objesine çevirmeden raw data döndür
  Future<Map<String, dynamic>> fetchInitialData(String token) async {
    final categoriesData = await ApiService.fetchCategoriesForBusiness(token);
    final menuItemsData = await ApiService.fetchMenuItemsForBusiness(token);
    
    return {
      'categories': categoriesData,
      'menuItems': menuItemsData, // 🔧 RAW DATA - MenuItem.fromJson() kaldırıldı
    };
  }

  Future<int> getCurrentMenuItemCount(String token) async {
    final menuItemsData = await ApiService.fetchMenuItemsForBusiness(token);
    return menuItemsData.length;
  }

  Future<void> createMenuItem({
    required String token,
    required int businessId,
    required MenuItemFormData formData,
  }) async {
    String? imageUrl;
    
    if (formData.hasImage) {
      imageUrl = await _uploadImage(businessId, formData);
    }

    await ApiService.createMenuItemForBusiness(
      token,
      businessId,
      formData.name,
      formData.description,
      formData.selectedCategoryId,
      imageUrl,
      formData.kdvRate,
    );
  }

  Future<String?> _uploadImage(int businessId, MenuItemFormData formData) async {
    String fileName = formData.pickedImageXFile != null
        ? p.basename(formData.pickedImageXFile!.path)
        : 'menu_item_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    String firebaseFileName = "business_$businessId/menu_items/${DateTime.now().millisecondsSinceEpoch}_$fileName";

    final imageUrl = await FirebaseStorageService.uploadImage(
      imageFile: formData.pickedImageXFile != null ? File(formData.pickedImageXFile!.path) : null,
      imageBytes: formData.webImageBytes,
      fileName: firebaseFileName,
      folderPath: 'menu_item_images',
    );
    
    if (imageUrl == null) {
      throw Exception('Firebase upload failed');
    }
    
    return imageUrl;
  }

  Future<List<dynamic>> createMenuItemsFromTemplates({
    required String token,
    required List<int> templateIds,
    required int targetCategoryId,
  }) async {
    return await ApiService.createMenuItemsFromTemplates(
      token,
      templateIds: templateIds,
      targetCategoryId: targetCategoryId,
    );
  }

  Future<void> deleteMenuItem(String token, int menuItemId) async {
    await ApiService.deleteMenuItem(token, menuItemId);
  }
}
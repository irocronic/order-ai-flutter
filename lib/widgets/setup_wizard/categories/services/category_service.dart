// lib/widgets/setup_wizard/categories/services/category_service.dart
import 'dart:convert';
import '../../../../services/api_service.dart';
import '../../../../services/firebase_storage_service.dart';
import '../../../../services/kds_management_service.dart';
import '../../../../models/kds_screen_model.dart';
import '../models/category_form_data.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class CategoryService {
  Future<Map<String, dynamic>> fetchInitialData(String token, int businessId) async {
    final results = await Future.wait([
      ApiService.fetchCategoriesForBusiness(token),
      KdsManagementService.fetchKdsScreens(token, businessId),
    ]);

    return {
      'categories': results[0] as List<dynamic>,
      'kdsScreens': (results[1] as List<KdsScreenModel>).where((kds) => kds.isActive).toList(),
    };
  }

  Future<int> getCurrentCategoryCount(String token) async {
    final categoriesData = await ApiService.fetchCategoriesForBusiness(token);
    return categoriesData.length;
  }

  Future<void> createCategory({
    required String token,
    required int businessId,
    required CategoryFormData formData,
  }) async {
    String? imageUrl;
    
    if (formData.hasImage) {
      imageUrl = await _uploadImage(businessId, formData);
    }

    await ApiService.createCategoryForBusiness(
      token,
      businessId,
      formData.name,
      formData.selectedParentCategoryId,
      imageUrl,
      formData.selectedKdsScreenId,
      formData.kdvRate,
    );
  }

  Future<String?> _uploadImage(int businessId, CategoryFormData formData) async {
    String fileName = formData.pickedImageXFile != null
        ? p.basename(formData.pickedImageXFile!.path)
        : 'category_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    String firebaseFileName = "business_$businessId/categories/${DateTime.now().millisecondsSinceEpoch}_$fileName";

    final imageUrl = await FirebaseStorageService.uploadImage(
      imageFile: formData.pickedImageXFile != null ? File(formData.pickedImageXFile!.path) : null,
      imageBytes: formData.webImageBytes,
      fileName: firebaseFileName,
      folderPath: 'category_images',
    );
    
    if (imageUrl == null) {
      throw Exception('Firebase upload failed');
    }
    
    return imageUrl;
  }

  Future<void> deleteCategory(String token, int categoryId) async {
    await ApiService.deleteCategory(token, categoryId);
  }
}
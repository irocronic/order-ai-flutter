// lib/widgets/setup_wizard/menu_items/services/template_selection_service.dart
import '../../../../services/api_service.dart';
import '../../../../services/localized_template_service.dart';
import '../../../../providers/language_provider.dart';
import 'package:flutter/foundation.dart';

class TemplateSelectionService {
  final String token;

  TemplateSelectionService(this.token);

  // ✅ GÜNCELLEME: Dil değişikliğini dinamik olarak algılayacak şekilde güncellendi
  Future<List<dynamic>> fetchTemplatesForCategory(String categoryName) async {
    // Her çağrıda güncel dil kodunu al
    final currentLanguageCode = LanguageProvider.currentLanguageCode;
    
    if (kDebugMode) {
      print('🌐 fetchTemplatesForCategory using language: $currentLanguageCode for category: $categoryName');
    }
    
    try {
      // Önce yerel JSON dosyasından yükle
      final localTemplates = await LocalizedTemplateService.loadMenuItemsForCategory(
        currentLanguageCode, 
        categoryName
      );
      
      if (kDebugMode) {
        print('📚 Loaded ${localTemplates.length} templates from JSON for $categoryName (Language: $currentLanguageCode)');
      }
      
      if (localTemplates.isNotEmpty) {
        return localTemplates;
      }
      
      // JSON'da bulunamazsa API'den yükle (fallback)
      if (kDebugMode) {
        print('⚠️ No templates found in JSON, trying API fallback');
      }
      
      return await ApiService.fetchMenuItemTemplates(
        token,
        categoryTemplateName: categoryName,
      );
    } catch (e) {
      // Hata durumunda API'den dene
      if (kDebugMode) {
        print('❌ JSON template loading failed: $e, trying API');
      }
      
      try {
        return await ApiService.fetchMenuItemTemplates(
          token,
          categoryTemplateName: categoryName,
        );
      } catch (apiError) {
        if (kDebugMode) {
          print('❌ Template yükleme hatası - JSON: $e, API: $apiError');
        }
        return [];
      }
    }
  }

  // ✅ GÜNCELLEME: Varyant şablonları için JSON desteği ve dil desteği
  Future<List<dynamic>> fetchVariantTemplatesForCategory(String categoryName) async {
    // Her çağrıda güncel dil kodunu al
    final currentLanguageCode = LanguageProvider.currentLanguageCode;
    
    if (kDebugMode) {
      print('🌐 fetchVariantTemplatesForCategory using language: $currentLanguageCode for category: $categoryName');
    }
    
    try {
      // Önce yerel JSON dosyasından kategori bazlı varyantları yükle
      final menuItems = await LocalizedTemplateService.loadMenuItemsForCategory(
        currentLanguageCode, 
        categoryName
      );
      
      List<dynamic> allVariants = [];
      for (var menuItem in menuItems) {
        final variants = await LocalizedTemplateService.loadVariantsForMenuItem(
          currentLanguageCode, 
          menuItem['id']
        );
        allVariants.addAll(variants);
      }
      
      if (kDebugMode) {
        print('📚 Loaded ${allVariants.length} variants from JSON for $categoryName (Language: $currentLanguageCode)');
      }
      
      if (allVariants.isNotEmpty) {
        return allVariants;
      }
      
      // JSON'da bulunamazsa API'den yükle
      if (kDebugMode) {
        print('⚠️ No variants found in JSON, trying API fallback');
      }
      
      return await ApiService.fetchVariantTemplates(
        token,
        categoryTemplateName: categoryName,
      );
    } catch (e) {
      // Fallback to API
      if (kDebugMode) {
        print('❌ JSON variant loading failed: $e, trying API');
      }
      
      try {
        return await ApiService.fetchVariantTemplates(
          token,
          categoryTemplateName: categoryName,
        );
      } catch (apiError) {
        if (kDebugMode) {
          print('❌ Varyant template yükleme hatası - JSON: $e, API: $apiError');
        }
        return [];
      }
    }
  }

  Future<List<dynamic>> fetchDefaultVariantTemplates() async {
    // Her çağrıda güncel dil kodunu al
    final currentLanguageCode = LanguageProvider.currentLanguageCode;
    
    if (kDebugMode) {
      print('🌐 fetchDefaultVariantTemplates using language: $currentLanguageCode');
    }
    
    try {
      // Varsayılan varyantları JSON'dan yükle
      final allVariants = await LocalizedTemplateService.loadVariants(currentLanguageCode);
      
      if (kDebugMode) {
        print('📚 Loaded ${allVariants.length} default variants from JSON (Language: $currentLanguageCode)');
      }
      
      if (allVariants.isNotEmpty) {
        return allVariants;
      }
      
      // JSON'da yoksa API'den yükle
      if (kDebugMode) {
        print('⚠️ No default variants found in JSON, trying API fallback');
      }
      
      return await ApiService.fetchVariantTemplates(token);
    } catch (e) {
      if (kDebugMode) {
        print('❌ JSON default variant loading failed: $e, trying API');
      }
      
      try {
        return await ApiService.fetchVariantTemplates(token);
      } catch (apiError) {
        if (kDebugMode) {
          print('❌ Varsayılan varyant yükleme hatası - JSON: $e, API: $apiError');
        }
        return [];
      }
    }
  }
}
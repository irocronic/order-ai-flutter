// lib/services/localized_template_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class LocalizedTemplateService {
  static Future<List<dynamic>> loadCategories(String languageCode) async {
    debugPrint('🏷️ [LocalizedTemplateService] loadCategories() çağrıldı');
    debugPrint('🌐 [LocalizedTemplateService] İstenen dil kodu: $languageCode');
    
    final result = await _loadJsonList('assets/i18n/categories', '${languageCode}_categories.json');
    
    debugPrint('📋 [LocalizedTemplateService] loadCategories() sonucu: ${result.length} kategori yüklendi');
    if (result.isNotEmpty) {
      debugPrint('🎯 [LocalizedTemplateService] İlk kategori örneği: ${result.first}');
    }
    
    return result;
  }

  static Future<List<dynamic>> loadMenuItems(String languageCode) async {
    debugPrint('🍽️ [LocalizedTemplateService] loadMenuItems() çağrıldı');
    debugPrint('🌐 [LocalizedTemplateService] İstenen dil kodu: $languageCode');
    
    final result = await _loadJsonList('assets/i18n/menu_items', '${languageCode}_menu_items.json');
    
    debugPrint('📋 [LocalizedTemplateService] loadMenuItems() sonucu: ${result.length} menü öğesi yüklendi');
    
    return result;
  }

  static Future<List<dynamic>> loadVariants(String languageCode) async {
    debugPrint('🔧 [LocalizedTemplateService] loadVariants() çağrıldı');
    debugPrint('🌐 [LocalizedTemplateService] İstenen dil kodu: $languageCode');
    
    final result = await _loadJsonList('assets/i18n/variants', '${languageCode}_variants.json');
    
    debugPrint('📋 [LocalizedTemplateService] loadVariants() sonucu: ${result.length} varyant yüklendi');
    
    return result;
  }

  // YENİ: Kategori bazlı menü öğeleri yükleme
  static Future<List<dynamic>> loadMenuItemsForCategory(String languageCode, String categoryName) async {
    debugPrint('🎯 [LocalizedTemplateService] loadMenuItemsForCategory() çağrıldı');
    debugPrint('🌐 [LocalizedTemplateService] Dil kodu: $languageCode, Kategori: $categoryName');
    
    try {
      final allMenuItems = await loadMenuItems(languageCode);
      debugPrint('📦 [LocalizedTemplateService] Toplam menü öğesi: ${allMenuItems.length}');
      
      // Önce kategori ID'sini bul
      final categories = await loadCategories(languageCode);
      debugPrint('🏷️ [LocalizedTemplateService] Toplam kategori: ${categories.length}');
      
      final category = categories.firstWhere(
        (cat) => cat['name'].toString().toLowerCase() == categoryName.toLowerCase(),
        orElse: () => null,
      );
      
      if (category == null) {
        debugPrint('❌ [LocalizedTemplateService] Kategori bulunamadı: $categoryName');
        debugPrint('📝 [LocalizedTemplateService] Mevcut kategoriler: ${categories.map((c) => c['name']).toList()}');
        return [];
      }
      
      final categoryId = category['id'];
      debugPrint('🆔 [LocalizedTemplateService] Bulunan kategori ID: $categoryId');
      
      // Bu kategoriye ait menü öğelerini filtrele
      final filteredItems = allMenuItems.where((item) => item['category_id'] == categoryId).toList();
      debugPrint('✅ [LocalizedTemplateService] Kategori için filtrelenen öğe sayısı: ${filteredItems.length}');
      
      return filteredItems;
    } catch (e) {
      debugPrint('💥 [LocalizedTemplateService] loadMenuItemsForCategory hatası: $e');
      return [];
    }
  }

  // YENİ: Varyant şablonlarını menü öğesi bazlı yükleme
  static Future<List<dynamic>> loadVariantsForMenuItem(String languageCode, int menuItemId) async {
    debugPrint('🔧 [LocalizedTemplateService] loadVariantsForMenuItem() çağrıldı');
    debugPrint('🌐 [LocalizedTemplateService] Dil kodu: $languageCode, Menü ID: $menuItemId');
    
    try {
      final allVariants = await loadVariants(languageCode);
      final filteredVariants = allVariants.where((variant) => variant['menu_item_id'] == menuItemId).toList();
      
      debugPrint('✅ [LocalizedTemplateService] Menü öğesi için varyant sayısı: ${filteredVariants.length}');
      
      return filteredVariants;
    } catch (e) {
      debugPrint('💥 [LocalizedTemplateService] loadVariantsForMenuItem hatası: $e');
      return [];
    }
  }

  static Future<List<dynamic>> _loadJsonList(String dir, String fileName) async {
    debugPrint('📂 [LocalizedTemplateService] _loadJsonList() başladı');
    debugPrint('📁 [LocalizedTemplateService] Dizin: $dir');
    debugPrint('📄 [LocalizedTemplateService] Dosya adı: $fileName');
    debugPrint('🔗 [LocalizedTemplateService] Tam yol: $dir/$fileName');
    
    try {
      debugPrint('🔄 [LocalizedTemplateService] JSON dosyası yükleniyor...');
      final String data = await rootBundle.loadString('$dir/$fileName');
      
      debugPrint('✅ [LocalizedTemplateService] JSON dosyası başarıyla yüklendi!');
      debugPrint('📏 [LocalizedTemplateService] Veri boyutu: ${data.length} karakter');
      
      final List<dynamic> parsedData = jsonDecode(data) as List<dynamic>;
      debugPrint('🎯 [LocalizedTemplateService] JSON parse edildi: ${parsedData.length} öğe');
      
      return parsedData;
    } catch (e) {
      debugPrint('❌ [LocalizedTemplateService] JSON yükleme hatası: $e');
      debugPrint('📄 [LocalizedTemplateService] Hatalı dosya: $dir/$fileName');
      
      // Fallback: Türkçe dosyayı yükle
      if (!fileName.startsWith('tr_')) {
        debugPrint('🔄 [LocalizedTemplateService] Fallback başlatılıyor...');
        final fallback = fileName.replaceFirst(RegExp(r'^[a-z]{2}_'), 'tr_');
        debugPrint('📄 [LocalizedTemplateService] Fallback dosyası: $dir/$fallback');
        
        try {
          debugPrint('🔄 [LocalizedTemplateService] Türkçe fallback yükleniyor...');
          final String fallbackData = await rootBundle.loadString('$dir/$fallback');
          
          debugPrint('✅ [LocalizedTemplateService] Türkçe fallback başarılı!');
          debugPrint('📏 [LocalizedTemplateService] Fallback veri boyutu: ${fallbackData.length} karakter');
          
          final List<dynamic> parsedFallbackData = jsonDecode(fallbackData) as List<dynamic>;
          debugPrint('🎯 [LocalizedTemplateService] Türkçe fallback parse edildi: ${parsedFallbackData.length} öğe');
          
          return parsedFallbackData;
        } catch (fallbackError) {
          debugPrint('💥 [LocalizedTemplateService] Türkçe fallback da başarısız: $fallbackError');
          debugPrint('📄 [LocalizedTemplateService] Fallback dosyası da bulunamadı: $dir/$fallback');
        }
      }
      
      debugPrint('🚫 [LocalizedTemplateService] Hiçbir dosya yüklenemedi, boş liste döndürülüyor');
      return [];
    }
  }
}
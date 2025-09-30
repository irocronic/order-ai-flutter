// lib/widgets/setup_wizard/menu_items/services/variant_template_service.dart
import 'package:flutter/foundation.dart';
import '../../../../services/api_service.dart';
import '../../../../services/localized_template_service.dart';
import '../../../../providers/language_provider.dart';

class VariantTemplateService {
  Future<List<dynamic>> loadVariantTemplates(
    Map<String, dynamic> menuItem,
    String token,
  ) async {
    final category = menuItem['category'];
    String? categoryName;
    
    if (category != null) {
      if (category is Map<String, dynamic>) {
        categoryName = category['name'] as String?;
      }
    }

    List<dynamic> templates = [];
    
    // Öncelikle JSON dosyasından varyant şablonlarını yükle
    try {
      final languageCode = LanguageProvider.currentLanguageCode;
      final jsonTemplates = await LocalizedTemplateService.loadVariants(languageCode);
      
      if (jsonTemplates.isNotEmpty) {
        // Kategori bazlı filtreleme yapabiliriz (opsiyonel)
        if (categoryName != null) {
          templates = jsonTemplates.take(8).toList();
        } else {
          templates = jsonTemplates.take(8).toList();
        }
        
        debugPrint('✅ JSON\'dan ${templates.length} varyant şablonu yüklendi');
      }
    } catch (jsonError) {
      debugPrint('⚠️ JSON varyant şablonları yüklenemedi: $jsonError');
      templates = getDefaultVariantTemplates();
      debugPrint('✅ Varsayılan şablonlar kullanılıyor: ${templates.length} adet');
    }
    
    // Eğer JSON'dan hiç template yüklenmediyse API'den dene
    if (templates.isEmpty) {
      try {
        if (categoryName != null) {
          templates = await ApiService.fetchVariantTemplates(
            token,
            categoryTemplateName: categoryName,
          );
          debugPrint('✅ API\'den kategori bazlı ${templates.length} varyant şablonu yüklendi');
        }

        if (templates.isEmpty) {
          final defaultTemplates = await ApiService.fetchVariantTemplates(token);
          templates = defaultTemplates.take(6).toList();
          debugPrint('✅ API\'den varsayılan ${templates.length} varyant şablonu yüklendi');
        }
      } catch (apiError) {
        debugPrint('❌ API varyant şablonları da yüklenemedi: $apiError');
        templates = getDefaultVariantTemplates();
        throw Exception('Şablonlar yüklenemedi, varsayılan seçenekler kullanılıyor.');
      }
    }

    return templates;
  }

  List<dynamic> getDefaultVariantTemplates() {
    return [
      {
        'id': -1,
        'name': 'Büyük',
        'price_multiplier': 1.3,
        'is_extra': false,
        'icon_name': 'restaurant'
      },
      {
        'id': -2,
        'name': 'Orta',
        'price_multiplier': 1.0,
        'is_extra': false,
        'icon_name': 'restaurant_outlined'
      },
      {
        'id': -3,
        'name': 'Küçük',
        'price_multiplier': 0.8,
        'is_extra': false,
        'icon_name': 'restaurant_outlined'
      },
      {
        'id': -4,
        'name': 'Ekstra Malzemeli',
        'price_multiplier': 1.2,
        'is_extra': true,
        'icon_name': 'add_circle'
      },
      {
        'id': -5,
        'name': 'Az Baharatlı',
        'price_multiplier': 1.0,
        'is_extra': false,
        'icon_name': 'whatshot'
      },
      {
        'id': -6,
        'name': 'Çok Baharatlı',
        'price_multiplier': 1.1,
        'is_extra': false,
        'icon_name': 'whatshot'
      },
    ];
  }
}
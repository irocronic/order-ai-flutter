// lib/widgets/setup_wizard/menu_items/services/menu_item_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../../../services/api_service.dart';
import '../../../../services/firebase_storage_service.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_item_variant.dart';
import '../models/menu_item_form_data.dart';
import '../models/variant_template_config.dart';
import '../utils/newly_added_tracker.dart'; // ✅ YENİ: Import ekle
import 'package:path/path.dart' as p;
import 'dart:io';

class MenuItemService {
  Future<Map<String, dynamic>> fetchInitialData(String token) async {
    final categoriesData = await ApiService.fetchCategoriesForBusiness(token);
    final menuItemsData = await ApiService.fetchMenuItemsForBusiness(token);
    
    return {
      'categories': categoriesData,
      'menuItems': menuItemsData,
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

  Future<void> createMenuItemSmart({
    required String token,
    required int businessId,
    required MenuItemFormData formData,
    required bool isFromRecipe,
    double? price,
  }) async {
    String? imageUrl;
    
    if (formData.hasImage) {
      imageUrl = await _uploadImage(businessId, formData);
    }

    // --- GÜNCELLENDİ: businessId parametresi eklendi ---
    await ApiService.createMenuItemSmart(
      token,
      name: formData.name,
      description: formData.description,
      categoryId: formData.selectedCategoryId!,
      imageUrl: imageUrl,
      kdvRate: formData.kdvRate,
      isFromRecipe: isFromRecipe,
      price: price,
      businessId: businessId, // YENİ: businessId eklendi
    );
  }

  // ✅ GÜNCELLENME: Özel ürün oluşturma metodu - tracker eklendi
  Future<Map<String, dynamic>> createMenuItemCustom({
    required String token,
    required String name,
    required int targetCategoryId,
    required bool isFromRecipe,
    required double? price,
    required int businessId,
    required List<MenuItemVariant>? variants,
  }) async {
    try {
      if (kDebugMode) {
        print('📤 Creating custom menu item:');
        print('  - Name: $name');
        print('  - Category ID: $targetCategoryId');
        print('  - Is Recipe: $isFromRecipe');
        print('  - Price: $price');
        print('  - Business ID: $businessId');
        print('  - Variants: ${variants?.length ?? 0}');
      }

      // Mevcut ürünleri kontrol et ve benzersiz isim oluştur
      final existingMenuItems = await ApiService.fetchMenuItemsForBusiness(token);
      final uniqueName = _generateUniqueProductName(name, existingMenuItems);
      
      if (kDebugMode && uniqueName != name) {
        print('📝 Duplicate custom product name detected. Original: "$name", Unique: "$uniqueName"');
      }

      // Custom menu item oluştur
      final menuItemResponse = await ApiService.createMenuItemSmart(
        token,
        name: uniqueName, // Benzersiz isim kullan
        description: '',
        categoryId: targetCategoryId,
        imageUrl: null,
        kdvRate: 10.0,
        isFromRecipe: isFromRecipe,
        price: price,
        businessId: businessId,
      );

      if (kDebugMode) {
        print('✅ Custom menu item created successfully');
        print('📋 Created menu item data: $menuItemResponse');
      }

      final menuItemId = menuItemResponse['id'];
      
      // ✅ YENİ: Gerçek ürün ID'sini tracker'a ekle
      if (menuItemId != null) {
        NewlyAddedTracker.markSingleItemAsNew(menuItemId);
        if (kDebugMode) {
          print('🆕 Real menu item marked as new: $menuItemId for "$name"');
        }
      }

      // Varyantları oluştur
      if (variants != null && variants.isNotEmpty && menuItemId != null) {
        if (kDebugMode) {
          print('📤 Creating ${variants.length} variants for custom menu item $menuItemId');
        }

        for (final variant in variants) {
          try {
            await ApiService.createMenuItemVariant(
              token,
              menuItemId,
              variant.name,
              variant.price,
              variant.isExtra,
              variant.image.isNotEmpty ? variant.image : null,
            );

            if (kDebugMode) {
              print('✅ Variant created: ${variant.name} for menu item $menuItemId');
            }
          } catch (variantError) {
            if (kDebugMode) {
              print('❌ Error creating variant ${variant.name}: $variantError');
            }
            // Tek varyant hatası tüm işlemi durdurmasın
            continue;
          }
        }

        if (kDebugMode) {
          print('✅ ${variants.length} variants processed for custom menu item $menuItemId');
        }
      }

      return menuItemResponse;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Custom menu item creation error: $e');
      }
      
      // Hata türü analizi
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('business') && errorStr.contains('zorunlu')) {
        throw Exception('İşletme bilgisi eksik. Lütfen uygulamayı yeniden başlatın.');
      } else if (errorStr.contains('invalid') && errorStr.contains('category')) {
        throw Exception('Geçersiz kategori. Lütfen farklı bir kategori seçin.');
      } else if (errorStr.contains('already exists') || errorStr.contains('unique') || errorStr.contains('benzersiz')) {
        throw Exception('Bu isimde bir ürün zaten mevcut. Lütfen farklı bir isim deneyin.');
      } else if (errorStr.contains('price') && errorStr.contains('required')) {
        throw Exception('Manuel ürün için fiyat belirtmek zorunludur.');
      } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
        throw Exception('Yetki hatası. Lütfen tekrar giriş yapın.');
      } else if (errorStr.contains('403') || errorStr.contains('forbidden')) {
        throw Exception('Bu işlem için yetkiniz bulunmuyor.');
      } else if (errorStr.contains('limit')) {
        throw Exception('Ürün ekleme limitinize ulaştınız.');
      } else {
        throw Exception('Özel ürün oluşturulurken hata: $e');
      }
    }
  }

  // --- YENİ EKLENEN: Benzersiz isim oluşturma fonksiyonu ---
  String _generateUniqueProductName(String baseName, List<dynamic> existingMenuItems) {
    // Mevcut ürünlerin isimlerini al
    final existingNames = existingMenuItems
        .map((item) => item['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    
    // Eğer baseName zaten yoksa, onu kullan
    if (!existingNames.contains(baseName)) {
      return baseName;
    }
    
    // Varsa, sayı ekleyerek benzersiz hale getir
    int counter = 1;
    String uniqueName;
    
    do {
      uniqueName = '$baseName ($counter)';
      counter++;
    } while (existingNames.contains(uniqueName) && counter < 100); // Max 100 deneme
    
    return uniqueName;
  }

  // --- GÜNCELLENME: Template'ten gelişmiş ürün oluşturma - tracker eklendi ---
  Future<void> createMenuItemFromTemplateAdvanced({
    required String token,
    required int templateId,
    required int targetCategoryId,
    required bool isFromRecipe,
    double? price,
    int? businessId, // YENİ: businessId parametresi eklendi
    List<MenuItemVariant>? variants, // YENİ: Varyant listesi eklendi
    VariantTemplateConfig? variantConfig, // YENİ: Varyant config eklendi
  }) async {
    
    if (kDebugMode) {
      print("📤 Template processing: ID=$templateId, Category=$targetCategoryId, Recipe=$isFromRecipe, Price=$price, BusinessId=$businessId");
      if (variants != null && variants.isNotEmpty) {
        print("📤 Variants: ${variants.length} variants to be created");
      }
    }
    
    try {
      // Template data al
      final templateData = await _fetchTemplateData(token, templateId);
      
      if (kDebugMode) {
        print("📄 Template data alındı: ${templateData.keys.toList()}");
        print("📄 Template details: name=${templateData['name']}, kdv_rate=${templateData['kdv_rate']}");
      }
      
      // --- YENİ EKLENEN: Mevcut ürünleri kontrol et ---
      final existingMenuItems = await ApiService.fetchMenuItemsForBusiness(token);
      final baseName = templateData['name'] ?? 'İsimsiz Ürün';
      final uniqueName = _generateUniqueProductName(baseName, existingMenuItems);
      
      if (kDebugMode && uniqueName != baseName) {
        print("📝 Duplicate name detected. Original: '$baseName', Unique: '$uniqueName'");
      }
      
      // --- DEĞİŞTİRİLDİ: businessId parametresi eklendi ---
      try {
        final createdMenuItem = await ApiService.createMenuItemSmart(
          token,
          name: uniqueName, // YENİ: Benzersiz isim kullan
          description: templateData['description'] ?? '',
          categoryId: targetCategoryId,
          imageUrl: templateData['image'],
          kdvRate: (templateData['kdv_rate'] ?? 10.0).toDouble(),
          isFromRecipe: isFromRecipe,
          price: price,
          businessId: businessId, // YENİ: businessId eklendi
        );
        
        if (kDebugMode) {
          print("✅ Template successfully created via ApiService.createMenuItemSmart");
          print("📋 Created menu item data: $createdMenuItem");
        }
        
        // ✅ YENİ: Template ürün ID'sini tracker'a ekle
        final menuItemId = createdMenuItem['id'] ?? createdMenuItem['menu_item_id'];
        if (menuItemId != null) {
          NewlyAddedTracker.markSingleItemAsNew(menuItemId);
          if (kDebugMode) {
            print('🆕 Template menu item marked as new: $menuItemId for "$uniqueName"');
          }
        }
        
        // --- YENİ EKLENEN: Varyantları da oluştur ---
        if (variants != null && variants.isNotEmpty && createdMenuItem != null) {
          if (menuItemId != null) {
            await _createVariantsForMenuItem(
              token: token,
              menuItemId: menuItemId,
              variants: variants,
              variantConfig: variantConfig,
              businessId: businessId,
            );
            
            if (kDebugMode) {
              print("✅ ${variants.length} variants created for menu item $menuItemId");
            }
          } else {
            if (kDebugMode) {
              print("❌ Could not get menu item ID for variant creation");
            }
          }
        }
        
      } catch (apiError) {
        if (kDebugMode) {
          print("💥 ApiService.createMenuItemSmart error: $apiError");
          print("📋 Request data was:");
          print("   name: $uniqueName"); // YENİ: Unique name logla
          print("   description: ${templateData['description'] ?? ''}");
          print("   categoryId: $targetCategoryId");
          print("   imageUrl: ${templateData['image']}");
          print("   kdvRate: ${(templateData['kdv_rate'] ?? 10.0).toDouble()}");
          print("   isFromRecipe: $isFromRecipe");
          print("   price: $price");
          print("   businessId: $businessId"); // YENİ: businessId logı
        }
        
        // Hata türü analizi
        final errorStr = apiError.toString().toLowerCase();
        if (errorStr.contains('business') && errorStr.contains('zorunlu')) {
          throw Exception('İşletme bilgisi eksik. Lütfen uygulamayı yeniden başlatın.');
        } else if (errorStr.contains('invalid') && errorStr.contains('category')) {
          throw Exception('Geçersiz kategori. Lütfen farklı bir kategori seçin.');
        } else if (errorStr.contains('already exists') || errorStr.contains('unique') || errorStr.contains('benzersiz')) {
          // Bu durumda bile hala duplicate error alınıyorsa, daha aggressive unique name oluştur
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fallbackName = "${baseName}_$timestamp";
          
          if (kDebugMode) {
            print("🔄 Still duplicate after unique name generation. Trying fallback: '$fallbackName'");
          }
          
          try {
            final retryMenuItem = await ApiService.createMenuItemSmart(
              token,
              name: fallbackName,
              description: templateData['description'] ?? '',
              categoryId: targetCategoryId,
              imageUrl: templateData['image'],
              kdvRate: (templateData['kdv_rate'] ?? 10.0).toDouble(),
              isFromRecipe: isFromRecipe,
              price: price,
              businessId: businessId,
            );
            
            if (kDebugMode) {
              print("✅ Fallback name worked: '$fallbackName'");
            }
            
            // ✅ YENİ: Fallback ürün için de tracker'a ekle
            final retryMenuItemId = retryMenuItem['id'] ?? retryMenuItem['menu_item_id'];
            if (retryMenuItemId != null) {
              NewlyAddedTracker.markSingleItemAsNew(retryMenuItemId);
              if (kDebugMode) {
                print('🆕 Fallback menu item marked as new: $retryMenuItemId for "$fallbackName"');
              }
            }
            
            return; // Başarılı olduysa çık
          } catch (retryError) {
            if (kDebugMode) {
              print("💥 Even fallback name failed: $retryError");
            }
            throw Exception('Ürün ismi benzersiz hale getirilemedi. Lütfen manuel olarak farklı bir isim deneyin.');
          }
        } else if (errorStr.contains('price') && errorStr.contains('required')) {
          throw Exception('Manuel ürün için fiyat belirtmek zorunludur.');
        } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
          throw Exception('Yetki hatası. Lütfen tekrar giriş yapın.');
        } else if (errorStr.contains('403') || errorStr.contains('forbidden')) {
          throw Exception('Bu işlem için yetkiniz bulunmuyor.');
        } else if (errorStr.contains('limit')) {
          throw Exception('Ürün ekleme limitinize ulaştınız.');
        } else {
          // Genel hata
          throw Exception('Ürün oluşturulurken bir hata oluştu: ${apiError.toString()}');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print("💥 Template creation error: $e");
        
        // Hata türü analizi
        if (e.toString().contains('404')) {
          print("❌ 404 Error - Template bulunamadı");
        } else if (e.toString().contains('400')) {
          print("❌ 400 Error - Bad Request - Payload hatası");
        } else if (e.toString().contains('401')) {
          print("❌ 401 Error - Authentication hatası");
        } else if (e.toString().contains('403')) {
          print("❌ 403 Error - Permission hatası");
        } else if (e.toString().contains('500')) {
          print("❌ 500 Error - Server hatası");
        }
      }
      rethrow;
    }
  }

  // --- DÜZELTME: Varyant oluşturma metodu güncellendi ---
  Future<void> _createVariantsForMenuItem({
    required String token,
    required int menuItemId,
    required List<MenuItemVariant> variants,
    VariantTemplateConfig? variantConfig,
    int? businessId,
  }) async {
    
    for (final variant in variants) {
      try {
        String? variantImageUrl;
        
        // DÜZELTME: Varyant görselini variant objesinden al
        if (variant.image.isNotEmpty && variant.image != '') {
          variantImageUrl = variant.image;
          
          if (kDebugMode) {
            print("🔗 Using variant image URL: $variantImageUrl");
          }
        }
        // Eski kod: variantConfig'den fotoğraf almaya çalışıyordu
        
        // --- API ÇAĞRISINA FOTOĞRAF URL'İNİ EKLE ---
        await ApiService.createMenuItemVariant(
          token,
          menuItemId,
          variant.name,
          variant.price,
          variant.isExtra,
          variantImageUrl, // ✅ Bu URL şimdi doğru şekilde geçiriliyor
        );
        
        if (kDebugMode) {
          print("✅ Variant created: ${variant.name} for menu item $menuItemId${variantImageUrl != null ? ' with image' : ''}");
        }
        
      } catch (e) {
        if (kDebugMode) {
          print("❌ Error creating variant ${variant.name}: $e");
        }
        // Tek varyant hatası tüm işlemi durdurmasın
        continue;
      }
    }
  }

  // --- YENİ EKLENEN: Varyant görseli upload etme ---
  Future<String?> _uploadVariantImage({
    required int businessId,
    required VariantTemplateConfig variantConfig,
  }) async {
    if (!variantConfig.hasVariantImage) return null;
    
    String fileName = variantConfig.variantImageXFile != null
        ? p.basename(variantConfig.variantImageXFile!.path)
        : 'variant_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    String firebaseFileName = "business_$businessId/variants/${DateTime.now().millisecondsSinceEpoch}_$fileName";

    final imageUrl = await FirebaseStorageService.uploadImage(
      imageFile: variantConfig.variantImageXFile != null ? File(variantConfig.variantImageXFile!.path) : null,
      imageBytes: variantConfig.variantWebImageBytes,
      fileName: firebaseFileName,
      folderPath: 'variant_images',
    );
    
    if (imageUrl == null) {
      throw Exception('Varyant görseli upload failed');
    }
    
    return imageUrl;
  }

  Future<Map<String, dynamic>> _fetchTemplateData(String token, int templateId) async {
    if (kDebugMode) {
      print("📥 Fetching template data: $templateId");
    }
    
    try {
      final response = await http.get(
        ApiService.getUrl('/templates/menu-item-templates/$templateId/'),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (kDebugMode) {
        print("📥 Template fetch response: ${response.statusCode}");
        if (response.statusCode != 200) {
          print("📥 Template fetch response body: ${response.body}");
        }
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (kDebugMode) {
          print("📄 Template data received successfully");
        }
        return data;
      } else {
        if (kDebugMode) {
          print("❌ Template fetch error: ${response.statusCode} - ${response.body}");
        }
        throw Exception("Template data fetch failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Network error while fetching template: $e");
      }
      throw Exception("Template verisi alınırken ağ hatası: $e");
    }
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
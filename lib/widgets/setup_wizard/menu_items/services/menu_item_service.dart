// lib/widgets/setup_wizard/menu_items/services/menu_item_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../services/firebase_storage_service.dart';
import '../../../../services/localized_template_service.dart';
import '../../../../providers/language_provider.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_item_variant.dart';
import '../models/menu_item_form_data.dart';
import '../models/variant_template_config.dart';
import '../utils/newly_added_tracker.dart';
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
    required AppLocalizations l10n,
  }) async {
    String? imageUrl;
    
    if (formData.hasImage) {
      imageUrl = await _uploadImage(businessId, formData, l10n);
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
    required AppLocalizations l10n,
  }) async {
    String? imageUrl;
    
    if (formData.hasImage) {
      imageUrl = await _uploadImage(businessId, formData, l10n);
    }

    await ApiService.createMenuItemSmart(
      token,
      name: formData.name,
      description: formData.description,
      categoryId: formData.selectedCategoryId!,
      imageUrl: imageUrl,
      kdvRate: formData.kdvRate,
      isFromRecipe: isFromRecipe,
      price: price,
      businessId: businessId,
    );
  }

  Future<Map<String, dynamic>> createMenuItemCustom({
    required String token,
    required String name,
    required int targetCategoryId,
    required bool isFromRecipe,
    required double? price,
    required int businessId,
    required List<MenuItemVariant>? variants,
    required AppLocalizations l10n,
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

      final existingMenuItems = await ApiService.fetchMenuItemsForBusiness(token);
      final uniqueName = _generateUniqueProductName(name, existingMenuItems);
      
      if (kDebugMode && uniqueName != name) {
        print('📝 Duplicate custom product name detected. Original: "$name", Unique: "$uniqueName"');
      }

      final menuItemResponse = await ApiService.createMenuItemSmart(
        token,
        name: uniqueName,
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
      
      if (menuItemId != null) {
        NewlyAddedTracker.markSingleItemAsNew(menuItemId);
        if (kDebugMode) {
          print('🆕 Real menu item marked as new: $menuItemId for "$name"');
        }
      }

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
      
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('business') && errorStr.contains('zorunlu')) {
        throw Exception('İşletme bilgileri eksik. Lütfen işletme ayarlarınızı kontrol edin.');
      } else if (errorStr.contains('invalid') && errorStr.contains('category')) {
        throw Exception('Seçilen kategori geçersiz. Lütfen farklı bir kategori seçin.');
      } else if (errorStr.contains('already exists') || errorStr.contains('unique') || errorStr.contains('benzersiz')) {
        throw Exception('Bu isimde bir ürün zaten mevcut. Lütfen farklı bir isim deneyin.');
      } else if (errorStr.contains('price') && errorStr.contains('required')) {
        throw Exception('Manuel ürünler için fiyat belirtilmesi zorunludur.');
      } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
        throw Exception('Yetkilendirme hatası. Lütfen yeniden giriş yapın.');
      } else if (errorStr.contains('403') || errorStr.contains('forbidden')) {
        throw Exception('Bu işlem için yetkiniz bulunmuyor.');
      } else if (errorStr.contains('limit')) {
        throw Exception('Ürün ekleme limitinize ulaştınız. Planınızı yükseltin.');
      } else {
        throw Exception('Özel ürün oluşturulamadı: ${e.toString()}');
      }
    }
  }

  String _generateUniqueProductName(String baseName, List<dynamic> existingMenuItems) {
    final existingNames = existingMenuItems
        .map((item) => item['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    
    if (!existingNames.contains(baseName)) {
      return baseName;
    }
    
    int counter = 1;
    String uniqueName;
    
    do {
      uniqueName = '$baseName ($counter)';
      counter++;
    } while (existingNames.contains(uniqueName) && counter < 100);
    
    return uniqueName;
  }

  Future<void> createMenuItemFromTemplateAdvanced({
    required String token,
    required int templateId,
    required int targetCategoryId,
    required bool isFromRecipe,
    double? price,
    int? businessId,
    List<MenuItemVariant>? variants,
    VariantTemplateConfig? variantConfig,
    required AppLocalizations l10n,
  }) async {
    
    if (kDebugMode) {
      print("📤 Template processing: ID=$templateId, Category=$targetCategoryId, Recipe=$isFromRecipe, Price=$price, BusinessId=$businessId");
      if (variants != null && variants.isNotEmpty) {
        print("📤 Variants: ${variants.length} variants to be created");
      }
    }
    
    try {
      final templateData = await _fetchTemplateData(token, templateId, l10n);
      
      if (kDebugMode) {
        print("📄 Template data alındı: ${templateData.keys.toList()}");
        print("📄 Template details: name=${templateData['name']}, kdv_rate=${templateData['kdv_rate']}");
      }
      
      final existingMenuItems = await ApiService.fetchMenuItemsForBusiness(token);
      final baseName = templateData['name'] ?? 'İsimsiz Ürün';
      final uniqueName = _generateUniqueProductName(baseName, existingMenuItems);
      
      if (kDebugMode && uniqueName != baseName) {
        print("📝 Duplicate name detected. Original: '$baseName', Unique: '$uniqueName'");
      }
      
      try {
        final createdMenuItem = await ApiService.createMenuItemSmart(
          token,
          name: uniqueName,
          description: templateData['description'] ?? '',
          categoryId: targetCategoryId,
          imageUrl: templateData['image'],
          kdvRate: (templateData['kdv_rate'] ?? 10.0).toDouble(),
          isFromRecipe: isFromRecipe,
          price: price,
          businessId: businessId,
        );
        
        if (kDebugMode) {
          print("✅ Template successfully created via ApiService.createMenuItemSmart");
          print("📋 Created menu item data: $createdMenuItem");
        }
        
        final menuItemId = createdMenuItem['id'] ?? createdMenuItem['menu_item_id'];
        if (menuItemId != null) {
          NewlyAddedTracker.markSingleItemAsNew(menuItemId);
          if (kDebugMode) {
            print('🆕 Template menu item marked as new: $menuItemId for "$uniqueName"');
          }
        }
        
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
          print("   name: $uniqueName");
          print("   description: ${templateData['description'] ?? ''}");
          print("   categoryId: $targetCategoryId");
          print("   imageUrl: ${templateData['image']}");
          print("   kdvRate: ${(templateData['kdv_rate'] ?? 10.0).toDouble()}");
          print("   isFromRecipe: $isFromRecipe");
          print("   price: $price");
          print("   businessId: $businessId");
        }
        
        final errorStr = apiError.toString().toLowerCase();
        if (errorStr.contains('business') && errorStr.contains('zorunlu')) {
          throw Exception('İşletme bilgileri eksik. Lütfen işletme ayarlarınızı kontrol edin.');
        } else if (errorStr.contains('invalid') && errorStr.contains('category')) {
          throw Exception('Seçilen kategori geçersiz. Lütfen farklı bir kategori seçin.');
        } else if (errorStr.contains('already exists') || errorStr.contains('unique') || errorStr.contains('benzersiz')) {
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
            
            final retryMenuItemId = retryMenuItem['id'] ?? retryMenuItem['menu_item_id'];
            if (retryMenuItemId != null) {
              NewlyAddedTracker.markSingleItemAsNew(retryMenuItemId);
              if (kDebugMode) {
                print('🆕 Fallback menu item marked as new: $retryMenuItemId for "$fallbackName"');
              }
            }
            
            return;
          } catch (retryError) {
            if (kDebugMode) {
              print("💥 Even fallback name failed: $retryError");
            }
            throw Exception('Benzersiz ürün adı oluşturulamadı. Lütfen farklı bir isim deneyin.');
          }
        } else if (errorStr.contains('price') && errorStr.contains('required')) {
          throw Exception('Manuel ürünler için fiyat belirtilmesi zorunludur.');
        } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
          throw Exception('Yetkilendirme hatası. Lütfen yeniden giriş yapın.');
        } else if (errorStr.contains('403') || errorStr.contains('forbidden')) {
          throw Exception('Bu işlem için yetkiniz bulunmuyor.');
        } else if (errorStr.contains('limit')) {
          throw Exception('Ürün ekleme limitinize ulaştınız. Planınızı yükseltin.');
        } else {
          throw Exception('Ürün oluşturulamadı: ${apiError.toString()}');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        print("💥 Template creation error: $e");
        
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
        
        if (variant.image.isNotEmpty && variant.image != '') {
          variantImageUrl = variant.image;
          
          if (kDebugMode) {
            print("🔗 Using variant image URL: $variantImageUrl");
          }
        }
        
        await ApiService.createMenuItemVariant(
          token,
          menuItemId,
          variant.name,
          variant.price,
          variant.isExtra,
          variantImageUrl,
        );
        
        if (kDebugMode) {
          print("✅ Variant created: ${variant.name} for menu item $menuItemId${variantImageUrl != null ? ' with image' : ''}");
        }
        
      } catch (e) {
        if (kDebugMode) {
          print("❌ Error creating variant ${variant.name}: $e");
        }
        continue;
      }
    }
  }

  Future<String?> _uploadVariantImage({
    required int businessId,
    required VariantTemplateConfig variantConfig,
    required AppLocalizations l10n,
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
      throw Exception('Varyant görsel yüklemesi başarısız oldu.');
    }
    
    return imageUrl;
  }

  // ✅ EN ÖNEMLİ GÜNCELLEME: JSON fallback ile template data çekme
  Future<Map<String, dynamic>> _fetchTemplateData(String token, int templateId, AppLocalizations l10n) async {
    if (kDebugMode) {
      print("📥 Fetching template data: $templateId");
    }
    
    try {
      // Önce API'den dene
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
          print("📄 Template data received successfully from API");
        }
        return data;
      } else {
        // API'den alınamazsa JSON'dan fallback yap
        if (kDebugMode) {
          print("❌ Template fetch error from API: ${response.statusCode} - Trying JSON fallback");
        }
        throw Exception('API template not found, trying JSON fallback');
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ API error, trying JSON fallback: $e");
      }
      
      // JSON fallback
      try {
        final languageCode = LanguageProvider.currentLanguageCode;
        final allMenuItems = await LocalizedTemplateService.loadMenuItems(languageCode);
        
        // Template ID'ye göre ara
        final templateData = allMenuItems.firstWhere(
          (item) => item['id'] == templateId,
          orElse: () => null,
        );
        
        if (templateData != null) {
          if (kDebugMode) {
            print("✅ Template data found in JSON: ${templateData['name']}");
          }
          
          // JSON formatını API formatına uygun hale getir
          return {
            'id': templateData['id'],
            'name': templateData['name'],
            'description': templateData['description'] ?? '',
            'image': templateData['image'],
            'kdv_rate': templateData['kdv_rate'] ?? 10.0,
            'price': templateData['price'],
          };
        } else {
          if (kDebugMode) {
            print("❌ Template not found in JSON either");
          }
          throw Exception('Template bulunamadı (ID: $templateId)');
        }
      } catch (jsonError) {
        if (kDebugMode) {
          print("❌ JSON fallback also failed: $jsonError");
        }
        
        // Son çare olarak varsayılan değerler ver
        return {
          'id': templateId,
          'name': 'Ürün #$templateId',
          'description': 'Lezzetli ürün',
          'image': null,
          'kdv_rate': 10.0,
          'price': null,
        };
      }
    }
  }

  Future<String?> _uploadImage(int businessId, MenuItemFormData formData, AppLocalizations l10n) async {
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
      throw Exception('Firebase görsel yüklemesi başarısız oldu.');
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
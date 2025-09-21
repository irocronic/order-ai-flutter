// lib/widgets/setup_wizard/menu_items/components/menu_items_list_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import '../../../../services/api_service.dart';
import '../../../../services/firebase_storage_service.dart';
import '../utils/newly_added_tracker.dart';
import '../dialogs/menu_item_variants_dialog.dart';

class MenuItemsListSection extends StatefulWidget {
  final String token;
  final List<dynamic> menuItems;
  final List<dynamic> availableCategories;
  final bool isLoading;
  final VoidCallback onMenuItemDeleted;
  final Function(String, {bool isError}) onMessageChanged;
  final int businessId; // 🆕 YENİ EKLENEN

  const MenuItemsListSection({
    Key? key,
    required this.token,
    required this.menuItems,
    required this.availableCategories,
    required this.isLoading,
    required this.onMenuItemDeleted,
    required this.onMessageChanged,
    required this.businessId, // 🆕 YENİ EKLENEN
  }) : super(key: key);

  @override
  State<MenuItemsListSection> createState() => _MenuItemsListSectionState();
}

class _MenuItemsListSectionState extends State<MenuItemsListSection> {
  // 📷 YENİ EKLENEN: Upload durumları
  final Map<int, bool> _uploadingItems = {};
  final ImagePicker _picker = ImagePicker();

  Future<void> _deleteMenuItem(BuildContext context, int menuItemId, String menuItemName) async {
    final l10n = AppLocalizations.of(context)!;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogDeleteMenuItemTitle),
        content: Text('${menuItemName} ürününü silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.dialogButtonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.dialogButtonDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteMenuItem(widget.token, menuItemId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${menuItemName} ürünü silindi'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        widget.onMenuItemDeleted();
      } catch (e) {
        widget.onMessageChanged(
          'Ürün silinirken hata: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true,
        );
      }
    }
  }

  // 📷 YENİ EKLENEN: Fotoğraf upload işlevi
  Future<void> _uploadPhoto(int menuItemId, String menuItemName) async {
    try {
      // Loading durumunu başlat
      setState(() {
        _uploadingItems[menuItemId] = true;
      });

      // Fotoğraf seçim dialog'u göster
      final imageSource = await _showImageSourceDialog();
      if (imageSource == null) {
        setState(() {
          _uploadingItems[menuItemId] = false;
        });
        return;
      }

      // Fotoğraf seç
      final XFile? image = await _picker.pickImage(
        source: imageSource,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) {
        setState(() {
          _uploadingItems[menuItemId] = false;
        });
        return;
      }

      // Upload progress göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text('$menuItemName için fotoğraf yükleniyor...'),
            ],
          ),
          duration: const Duration(seconds: 30),
          backgroundColor: Colors.blue,
        ),
      );

      // Firebase'e upload et
      String? imageUrl = await _uploadImageToFirebase(image, menuItemId);
      
      if (imageUrl != null) {
        // API'yi güncelle
        await _updateMenuItemPhoto(menuItemId, imageUrl);
        
        // Success mesajı göster
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$menuItemName fotoğrafı başarıyla güncellendi!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Listeyi yenile
        widget.onMenuItemDeleted(); // Bu callback aslında refresh işlevi görüyor
      } else {
        throw Exception('Fotoğraf upload edilemedi');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf yüklenirken hata: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingItems[menuItemId] = false;
        });
      }
    }
  }

  // 📷 YENİ EKLENEN: Fotoğraf kaynağı seçim dialog'u
  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Fotoğraf Kaynağı'),
          content: const Text('Fotoğrafı nereden seçmek istiyorsunuz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Galeri'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Kamera'),
            ),
          ],
        );
      },
    );
  }

  // 📷 YENİ EKLENEN: Firebase'e fotoğraf upload
  Future<String?> _uploadImageToFirebase(XFile image, int menuItemId) async {
    try {
      String fileName = p.basename(image.path);
      String firebaseFileName = "menu_items/${menuItemId}/${DateTime.now().millisecondsSinceEpoch}_$fileName";

      String? imageUrl;
      
      if (kIsWeb) {
        // Web için bytes kullan
        Uint8List imageBytes = await image.readAsBytes();
        imageUrl = await FirebaseStorageService.uploadImage(
          imageBytes: imageBytes,
          fileName: firebaseFileName,
          folderPath: 'menu_item_images',
        );
      } else {
        // Mobile için file kullan
        File imageFile = File(image.path);
        imageUrl = await FirebaseStorageService.uploadImage(
          imageFile: imageFile,
          fileName: firebaseFileName,
          folderPath: 'menu_item_images',
        );
      }

      return imageUrl;
    } catch (e) {
      debugPrint('❌ Firebase upload error: $e');
      throw Exception('Firebase upload hatası: $e');
    }
  }

  // 📷 YENİ EKLENEN: API'de ürün fotoğrafını güncelle
  Future<void> _updateMenuItemPhoto(int menuItemId, String imageUrl) async {
    try {
      await ApiService.updateMenuItemPhoto(widget.token, menuItemId, imageUrl);
    } catch (e) {
      debugPrint('❌ API update error: $e');
      throw Exception('API güncelleme hatası: $e');
    }
  }

  // 🆕 YENİ EKLENEN: Varyant yönetimi dialog'unu aç
  Future<void> _openVariantsDialog(Map<String, dynamic> menuItem) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MenuItemVariantsDialog(
        token: widget.token,
        businessId: widget.businessId, // 🆕 YENİ: widget.businessId kullan
        menuItem: menuItem,
        onVariantsChanged: () {
          // Varyant değişikliği olduğunda ana listeyi yenile
          widget.onMenuItemDeleted(); // Bu callback refresh işlevi görüyor
        },
      ),
    );
  }

  String _getCategoryName(dynamic menuItem) {
    try {
      if (menuItem != null && menuItem is Map<String, dynamic>) {
        final category = menuItem['category'];
        
        if (category != null) {
          if (category is Map<String, dynamic>) {
            final categoryName = category['name'];
            if (categoryName != null && categoryName.toString().trim().isNotEmpty) {
              return categoryName.toString();
            }
          } 
          else if (category is int || category is String) {
            final categoryId = category is String ? int.tryParse(category) : category as int;
            
            if (categoryId != null && widget.availableCategories.isNotEmpty) {
              final foundCategory = widget.availableCategories.firstWhereOrNull(
                (cat) {
                  if (cat != null && cat is Map<String, dynamic>) {
                    final catId = cat['id'];
                    return catId == categoryId;
                  }
                  return false;
                },
              );
              
              if (foundCategory != null && foundCategory is Map<String, dynamic>) {
                final categoryName = foundCategory['name'];
                if (categoryName != null && categoryName.toString().trim().isNotEmpty) {
                  return categoryName.toString();
                }
              }
            }
          }
        }
        
        final categoryId = menuItem['category_id'];
        if (categoryId != null && widget.availableCategories.isNotEmpty) {
          final foundCategory = widget.availableCategories.firstWhereOrNull(
            (cat) => cat != null && cat is Map<String, dynamic> && cat['id'] == categoryId,
          );
          if (foundCategory != null && foundCategory is Map<String, dynamic>) {
            final categoryName = foundCategory['name'];
            if (categoryName != null && categoryName.toString().trim().isNotEmpty) {
              return categoryName.toString();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Category name error: $e');
    }
    return 'Kategori Yok';
  }

  String _getMenuItemName(dynamic menuItem) {
    try {
      if (menuItem != null && menuItem is Map<String, dynamic>) {
        final name = menuItem['name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString().trim();
        }
        
        final title = menuItem['title'];
        if (title != null && title.toString().trim().isNotEmpty) {
          return title.toString().trim();
        }
        
        final itemName = menuItem['item_name'];
        if (itemName != null && itemName.toString().trim().isNotEmpty) {
          return itemName.toString().trim();
        }
      }
    } catch (e) {
      debugPrint('❌ Menu item name error: $e');
    }
    return 'İsimsiz Ürün';
  }

  int? _getMenuItemId(dynamic menuItem) {
    try {
      if (menuItem != null && menuItem is Map<String, dynamic>) {
        final id = menuItem['id'];
        if (id is int) return id;
        if (id is String) return int.tryParse(id);
      }
    } catch (e) {
      debugPrint('❌ Menu item id error: $e');
    }
    return null;
  }

  String? _getMenuItemImage(dynamic menuItem) {
    try {
      if (menuItem != null && menuItem is Map<String, dynamic>) {
        final image = menuItem['image'];
        if (image != null && image.toString().trim().isNotEmpty) {
          return image.toString();
        }
        
        final imageUrl = menuItem['image_url'];
        if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
          return imageUrl.toString();
        }
      }
    } catch (e) {
      debugPrint('❌ Menu item image error: $e');
    }
    return null;
  }

  String? _getMenuItemDescription(dynamic menuItem) {
    try {
      if (menuItem != null && menuItem is Map<String, dynamic>) {
        final description = menuItem['description'];
        if (description != null && description.toString().trim().isNotEmpty) {
          return description.toString().trim();
        }
      }
    } catch (e) {
      debugPrint('❌ Menu item description error: $e');
    }
    return null;
  }

  String _getKdvRate(dynamic menuItem) {
    try {
      if (menuItem != null && menuItem is Map<String, dynamic>) {
        final kdvRate = menuItem['kdv_rate'];
        if (kdvRate != null) {
          return kdvRate.toString();
        }
      }
    } catch (e) {
      debugPrint('❌ KDV rate error: $e');
    }
    return '10';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // ✅ DEBUG: Tracker durumunu kontrol et
    print('🔍 MenuItemsListSection build():');
    print('  - Total menu items: ${widget.menuItems.length}');
    print('  - NewlyAddedTracker items: ${NewlyAddedTracker.newlyAddedItems}');
    print('  - NewlyAddedTracker count: ${NewlyAddedTracker.newlyAddedCount}');
    
    // İlk 5 ürün için detaylı kontrol
    for (var i = 0; i < widget.menuItems.take(5).length; i++) {
      final item = widget.menuItems[i];
      final itemId = _getMenuItemId(item);
      final itemName = _getMenuItemName(item);
      if (itemId != null) {
        final isNew = NewlyAddedTracker.isNewlyAdded(itemId);
        print('  - [$i] Item "$itemName" (ID: $itemId): isNew=$isNew');
      } else {
        print('  - [$i] Item "$itemName": ID is null!');
      }
    }

    // ✅ GÜNCELLENME: NewlyAddedTracker kullan
    final sortedMenuItems = List<dynamic>.from(widget.menuItems);
    sortedMenuItems.sort((a, b) {
      final aId = _getMenuItemId(a);
      final bId = _getMenuItemId(b);
      
      if (aId != null && bId != null) {
        final aIsNew = NewlyAddedTracker.isNewlyAdded(aId);
        final bIsNew = NewlyAddedTracker.isNewlyAdded(bId);
        
        // Debug: Sıralama kararlarını logla
        if (aIsNew || bIsNew) {
          print('🔄 Sorting: Item $aId (new: $aIsNew) vs Item $bId (new: $bIsNew)');
        }
        
        // Yeni ürünler önce gelsin
        if (aIsNew && !bIsNew) return -1;
        if (!aIsNew && bIsNew) return 1;
        
        // İkisi de yeni ise veya ikisi de eski ise ID'ye göre ters sıralama (yeni ID'ler önce)
        return bId.compareTo(aId);
      }
      
      return 0;
    });

    // Debug: Sıralama sonucu
    print('📋 Sorted items (first 3):');
    for (var i = 0; i < sortedMenuItems.take(3).length; i++) {
      final item = sortedMenuItems[i];
      final itemId = _getMenuItemId(item);
      final itemName = _getMenuItemName(item);
      final isNew = itemId != null ? NewlyAddedTracker.isNewlyAdded(itemId) : false;
      print('  - [$i] "$itemName" (ID: $itemId) - NEW: $isNew');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupMenuItemsAddedTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Divider(color: Colors.white70),
        const SizedBox(height: 8),
        
        if (widget.isLoading && sortedMenuItems.isEmpty)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (sortedMenuItems.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.restaurant_menu_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noMenuItemsAdded,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount;
              
              if (constraints.maxWidth >= 900) {
                crossAxisCount = 6; // Desktop/Tablet: 6 sütun
              } else if (constraints.maxWidth >= 600) {
                crossAxisCount = 4; // Büyük Mobil: 4 sütun  
              } else {
                crossAxisCount = 3; // Küçük Mobil: 3 sütun
              }
              
              return MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
                itemCount: sortedMenuItems.length,
                itemBuilder: (context, index) {
                  final menuItem = sortedMenuItems[index];
                  return _buildMenuItemCard(context, menuItem, l10n);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildMenuItemCard(BuildContext context, dynamic menuItem, AppLocalizations l10n) {
    final menuItemName = _getMenuItemName(menuItem);
    final menuItemId = _getMenuItemId(menuItem);
    final categoryName = _getCategoryName(menuItem);
    final imageUrl = _getMenuItemImage(menuItem);
    final description = _getMenuItemDescription(menuItem);
    final kdvRate = _getKdvRate(menuItem);

    // ✅ GÜNCELLENME: NewlyAddedTracker kullan ve debug log ekle
    final isNewlyAdded = menuItemId != null ? NewlyAddedTracker.isNewlyAdded(menuItemId) : false;
    
    // 📷 YENİ EKLENEN: Upload durumu kontrolü
    final isUploading = menuItemId != null ? (_uploadingItems[menuItemId] ?? false) : false;
    
    // Debug: Her kart için yeni ürün durumunu logla
    if (isNewlyAdded) {
      print('🆕 Building NEW card for: "$menuItemName" (ID: $menuItemId)');
    }

    return Card(
      margin: EdgeInsets.zero,
      color: isNewlyAdded 
          ? Colors.green.withOpacity(0.15) // ✅ YENİ: Yeni ürünler için yeşil arka plan
          : Colors.white.withOpacity(0.1),
      elevation: isNewlyAdded ? 4 : 0, // ✅ YENİ: Yeni ürünler için yüksek elevation
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isNewlyAdded 
              ? Colors.green.withOpacity(0.5) // ✅ YENİ: Yeni ürünler için yeşil border
              : Colors.white.withOpacity(0.2),
          width: isNewlyAdded ? 2 : 1, // ✅ YENİ: Yeni ürünler için kalın border
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Stack( // ✅ YENİ: Stack ile badge overlay
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 📷 GÜNCELLENME: Fotoğraf alanı - upload butonu eklendi
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isNewlyAdded 
                                ? Colors.green.withOpacity(0.2) // ✅ YENİ: Yeni ürünler için yeşil resim arka planı
                                : Colors.white.withOpacity(0.1),
                          ),
                          child: imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, o, s) => Icon(
                                      Icons.fastfood_outlined,
                                      size: 28,
                                      color: isNewlyAdded 
                                          ? Colors.green.shade200 // ✅ YENİ: Yeni ürünler için yeşil icon
                                          : Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.fastfood_outlined,
                                  size: 28,
                                  color: isNewlyAdded 
                                      ? Colors.green.shade200 // ✅ YENİ: Yeni ürünler için yeşil icon
                                      : Colors.white.withOpacity(0.7),
                                ),
                        ),
                        
                        // 📷 YENİ EKLENEN: Upload butonu overlay (sadece fotoğraf yoksa)
                        if (imageUrl == null && menuItemId != null)
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: isUploading 
                                    ? null 
                                    : () => _uploadPhoto(menuItemId, menuItemName),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: isUploading
                                      ? Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Fotoğraf\nEkle',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        
                        // 📷 YENİ EKLENEN: Fotoğraf değiştir butonu (fotoğraf varsa)
                        if (imageUrl != null && menuItemId != null)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: isUploading 
                                      ? null 
                                      : () => _uploadPhoto(menuItemId, menuItemName),
                                  child: isUploading
                                      ? Center(
                                          child: SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.camera_alt,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Ürün adı - Resmin altında, ortada
                  Center(
                    child: Text(
                      menuItemName,
                      style: TextStyle(
                        color: isNewlyAdded 
                            ? Colors.green.shade100 // ✅ YENİ: Yeni ürünler için açık yeşil yazı
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Kategori - Ortada
                  Center(
                    child: Text(
                      categoryName.length > 12 ? '${categoryName.substring(0, 12)}...' : categoryName,
                      style: TextStyle(
                        fontSize: 11,
                        color: isNewlyAdded 
                            ? Colors.green.shade200 // ✅ YENİ: Yeni ürünler için yeşil kategori yazısı
                            : Colors.white.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // Açıklama (varsa)
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        description.length > 30 ? '${description.substring(0, 30)}...' : description,
                        style: TextStyle(
                          fontSize: 10,
                          color: isNewlyAdded 
                              ? Colors.green.shade300 // ✅ YENİ: Yeni ürünler için yeşil açıklama
                              : Colors.white.withOpacity(0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 8),
                  
                  // KDV bilgisi - ortada
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isNewlyAdded 
                            ? Colors.green.withOpacity(0.2) // ✅ YENİ: Yeni ürünler için yeşil KDV arka planı
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.percent,
                            size: 10,
                            color: isNewlyAdded 
                                ? Colors.green.shade200 // ✅ YENİ: Yeni ürünler için yeşil icon
                                : Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'KDV ${kdvRate}%',
                            style: TextStyle(
                              fontSize: 9,
                              color: isNewlyAdded 
                                  ? Colors.green.shade200 // ✅ YENİ: Yeni ürünler için yeşil yazı
                                  : Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 🎨 YENİ TASARIM: Daha görünür butonlar
                  if (menuItemId != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // 🎨 Düzenle butonu - Daha koyu sarı/turuncu arka plan
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.tune,
                                color: Colors.white,
                                size: 14,
                              ),
                              label: Text(
                                'Düzenle',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => _openVariantsDialog(menuItem as Map<String, dynamic>),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600, // 🎨 Daha koyu turuncu
                                foregroundColor: Colors.white,
                                elevation: 2, // 🎨 Hafif gölge
                                shadowColor: Colors.orange.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Colors.orange.shade700, // 🎨 Daha koyu border
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 6),
                        
                        // 🎨 Sil butonu - Daha koyu kırmızı arka plan
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                                size: 14,
                              ),
                              label: Text(
                                'Sil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => _deleteMenuItem(context, menuItemId, menuItemName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600, // 🎨 Daha koyu kırmızı
                                foregroundColor: Colors.white,
                                elevation: 2, // 🎨 Hafif gölge
                                shadowColor: Colors.red.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: Colors.red.shade700, // 🎨 Daha koyu border
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // ✅ YENİ: "YENİ" Badge - Sağ üst köşede
            if (isNewlyAdded)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_new,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'YENİ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
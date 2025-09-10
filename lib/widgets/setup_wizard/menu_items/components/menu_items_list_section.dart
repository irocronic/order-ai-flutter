// lib/widgets/setup_wizard/menu_items/components/menu_items_list_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../services/api_service.dart';

class MenuItemsListSection extends StatelessWidget {
  final String token;
  final List<dynamic> menuItems;
  final List<dynamic> availableCategories;
  final bool isLoading;
  final VoidCallback onMenuItemDeleted;
  final Function(String, {bool isError}) onMessageChanged;

  const MenuItemsListSection({
    Key? key,
    required this.token,
    required this.menuItems,
    required this.availableCategories,
    required this.isLoading,
    required this.onMenuItemDeleted,
    required this.onMessageChanged,
  }) : super(key: key);

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
        await ApiService.deleteMenuItem(token, menuItemId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${menuItemName} ürünü silindi'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        onMenuItemDeleted();
      } catch (e) {
        onMessageChanged(
          'Ürün silinirken hata: ${e.toString().replaceFirst("Exception: ", "")}',
          isError: true,
        );
      }
    }
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
            
            if (categoryId != null && availableCategories.isNotEmpty) {
              final foundCategory = availableCategories.firstWhereOrNull(
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
        if (categoryId != null && availableCategories.isNotEmpty) {
          final foundCategory = availableCategories.firstWhereOrNull(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupMenuItemsAddedTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Divider(color: Colors.white70),
        const SizedBox(height: 8),
        
        if (isLoading && menuItems.isEmpty)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (menuItems.isEmpty)
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
          // 📱 GÜNCELLENME: Daha yoğun grid layout
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
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final menuItem = menuItems[index];
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

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Container(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 📱 YENİ TASARIM: Üst kısım - Sadece resim (delete butonu kaldırıldı)
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.1),
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
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.fastfood_outlined,
                          size: 28,
                          color: Colors.white.withOpacity(0.7),
                        ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 📱 Ürün adı - Resmin altında, ortada
              Center(
                child: Text(
                  menuItemName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 6),
              
              // 📱 Kategori - Ortada
              Center(
                child: Text(
                  categoryName.length > 12 ? '${categoryName.substring(0, 12)}...' : categoryName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.7),
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
                      color: Colors.white.withOpacity(0.6),
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
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.percent,
                        size: 10,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'KDV ${kdvRate}%',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 🔧 YENİ: Delete butonu - En altta, KDV'nin altında
              if (menuItemId != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: double.infinity, // Tam genişlik
                    height: 32, // Sabit yükseklik
                    child: ElevatedButton.icon(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 16,
                      ),
                      label: Text(
                        'Sil',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: () => _deleteMenuItem(context, menuItemId, menuItemName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
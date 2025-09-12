// lib/widgets/setup_wizard/categories/components/categories_list_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../models/kds_screen_model.dart';
import '../../../../services/api_service.dart';

class CategoriesListSection extends StatelessWidget {
  final String token;
  final List<dynamic> categories;
  final List<KdsScreenModel> availableKdsScreens;
  final bool isLoading;
  final VoidCallback onCategoryDeleted;
  final Function(String, {bool isError}) onMessageChanged;

  const CategoriesListSection({
    Key? key,
    required this.token,
    required this.categories,
    required this.availableKdsScreens,
    required this.isLoading,
    required this.onCategoryDeleted,
    required this.onMessageChanged,
  }) : super(key: key);

  Future<void> _deleteCategory(BuildContext context, int categoryId, String categoryName) async {
    final l10n = AppLocalizations.of(context)!;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogDeleteCategoryTitle),
        content: Text(l10n.setupCategoriesDeleteDialogContent(categoryName)),
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
        await ApiService.deleteCategory(token, categoryId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.setupCategoriesInfoDeleted(categoryName)),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        onCategoryDeleted();
      } catch (e) {
        onMessageChanged(
          l10n.setupCategoriesErrorDeleting(e.toString().replaceFirst("Exception: ", "")),
          isError: true,
        );
      }
    }
  }

  String _getCategoryName(dynamic category) {
    try {
      if (category != null && category is Map<String, dynamic>) {
        final name = category['name'];
        if (name != null && name.toString().trim().isNotEmpty) {
          return name.toString().trim();
        }
      }
    } catch (e) {
      debugPrint('❌ Category name error: $e');
    }
    return 'İsimsiz Kategori';
  }

  int? _getCategoryId(dynamic category) {
    try {
      if (category != null && category is Map<String, dynamic>) {
        final id = category['id'];
        if (id is int) return id;
        if (id is String) return int.tryParse(id);
      }
    } catch (e) {
      debugPrint('❌ Category id error: $e');
    }
    return null;
  }

  String? _getCategoryImage(dynamic category) {
    try {
      if (category != null && category is Map<String, dynamic>) {
        final image = category['image'];
        if (image != null && image.toString().trim().isNotEmpty) {
          return image.toString();
        }
      }
    } catch (e) {
      debugPrint('❌ Category image error: $e');
    }
    return null;
  }

  String _getParentCategoryName(dynamic category) {
    try {
      if (category != null && category is Map<String, dynamic>) {
        final parent = category['parent'];
        if (parent != null) {
          final parentCat = categories.firstWhereOrNull(
            (c) => c != null && c is Map<String, dynamic> && c['id'] == parent
          );
          if (parentCat != null && parentCat is Map<String, dynamic>) {
            final parentName = parentCat['name'];
            if (parentName != null && parentName.toString().trim().isNotEmpty) {
              return parentName.toString().trim();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Parent category error: $e');
    }
    return '';
  }

  String _getKdsInfo(dynamic category) {
    try {
      if (category != null && category is Map<String, dynamic>) {
        final assignedKds = category['assigned_kds'];
        if (assignedKds != null) {
          if (assignedKds is Map<String, dynamic> && assignedKds['name'] != null) {
            return assignedKds['name'].toString();
          } else if (assignedKds is int) {
            final kdsScreen = availableKdsScreens.firstWhereOrNull(
              (kds) => kds.id == assignedKds
            );
            if (kdsScreen != null) {
              return kdsScreen.name;
            } else {
              return 'KDS ID: $assignedKds';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ KDS info error: $e');
    }
    return '';
  }

  String _getKdvRate(dynamic category) {
    try {
      if (category != null && category is Map<String, dynamic>) {
        final kdvRate = category['kdv_rate'];
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
          l10n.setupCategoriesAddedTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Divider(color: Colors.white70),
        const SizedBox(height: 8),
        
        if (isLoading && categories.isEmpty)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (categories.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noCategoriesAdded,
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
          // 📱 GÜNCELLENME: Staggered Grid Layout
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
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _buildCategoryCard(context, category, l10n);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, dynamic category, AppLocalizations l10n) {
    final categoryName = _getCategoryName(category);
    final categoryId = _getCategoryId(category);
    final imageUrl = _getCategoryImage(category);
    final parentName = _getParentCategoryName(category);
    final kdsInfo = _getKdsInfo(category);
    final kdvRate = _getKdvRate(category);

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
              // 📱 YENİ TASARIM: Üst kısım - Sadece resim
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
                              Icons.category_outlined,
                              size: 28,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.category_outlined,
                          size: 28,
                          color: Colors.white.withOpacity(0.7),
                        ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 📱 Kategori adı - Resmin altında, ortada
              Center(
                child: Text(
                  categoryName,
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
              
              // 📱 Parent kategori bilgisi (varsa)
              if (parentName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Alt: $parentName',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
              ],
              
              // KDS bilgisi (varsa)
              if (kdsInfo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: double.infinity),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monitor,
                          size: 10,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            kdsInfo.length > 8 ? '${kdsInfo.substring(0, 8)}...' : kdsInfo,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
              
              // 🎨 YENİ TASARIM: Daha görünür sil butonu
              if (categoryId != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: double.infinity, // Tam genişlik
                    height: 32, // Sabit yükseklik
                    child: ElevatedButton.icon(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.white, // 🎨 Beyaz icon
                        size: 14,
                      ),
                      label: Text(
                        'Sil',
                        style: TextStyle(
                          color: Colors.white, // 🎨 Beyaz yazı
                          fontSize: 11,
                          fontWeight: FontWeight.bold, // 🎨 Kalın yazı
                        ),
                      ),
                      onPressed: () => _deleteCategory(context, categoryId, categoryName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600, // 🎨 Daha koyu kırmızı arka plan
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
            ],
          ),
        ),
      ),
    );
  }
}
// lib/widgets/categorized_menu_list_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';
import '../models/menu_item.dart';
import '../models/menu_item_variant.dart';
import '../services/api_service.dart';
import '../controllers/categorized_menu_list_view_controller.dart';
import './dialogs/variant_selection_dialog.dart';
import '../widgets/shared/image_display.dart';
import '../utils/currency_formatter.dart';

class CategorizedMenuListView extends StatefulWidget {
  final List<MenuItem> menuItems;
  final List<dynamic> categories;
  final List<String> tableUsers;
  final Function(MenuItem item, MenuItemVariant? variant, List<MenuItemVariant> extras, String? tableUser, int quantity) onItemSelected;

  const CategorizedMenuListView({
    Key? key,
    required this.menuItems,
    required this.categories,
    required this.tableUsers,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  _CategorizedMenuListViewState createState() => _CategorizedMenuListViewState();
}

class _CategorizedMenuListViewState extends State<CategorizedMenuListView> {
  late CategorizedMenuListViewController _controller;
  Map<int, int> _itemPreQuantities = {};

  @override
  void initState() {
    super.initState();
    _controller = CategorizedMenuListViewController(
      allMenuItems: widget.menuItems,
      allCategories: widget.categories,
      onStateUpdate: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    for (var item in widget.menuItems) {
      _itemPreQuantities[item.id] = 1;
    }
  }

  void _incrementQuantity(int itemId) {
    if (!mounted) return;
    setState(() {
      _itemPreQuantities[itemId] = (_itemPreQuantities[itemId] ?? 1) + 1;
    });
  }

  void _decrementQuantity(int itemId) {
    if (!mounted) return;
    setState(() {
      if ((_itemPreQuantities[itemId] ?? 1) > 1) {
        _itemPreQuantities[itemId] = (_itemPreQuantities[itemId]!) - 1;
      }
    });
  }

  String getCategoryName(dynamic category, AppLocalizations l10n) {
    if (category == null || (category is Map && category['id'] == null)) return l10n.categoryAll;
    if (category is Map) {
      return category['name'] ?? l10n.unknownCategory;
    }
    return category.toString();
  }

  Widget _buildProductImage(MenuItem item) {
    String? productUrl;
    String? categoryImageUrl;

    if (item.image.isNotEmpty) {
      productUrl = item.image.startsWith('http') ? item.image : '${ApiService.baseUrl}${item.image}';
    }
    if(item.category != null && item.category is Map && item.category!['image'] != null) {
      final catImage = item.category!['image'];
      if (catImage.toString().isNotEmpty) {
        categoryImageUrl = catImage.toString().startsWith('http') ? catImage : '${ApiService.baseUrl}$catImage';
      }
    }
    final String displayImageUrl = productUrl ?? categoryImageUrl ?? '';

    return buildImage(
      displayImageUrl.isNotEmpty ? displayImageUrl : null,
      item.isCampaignBundle ? Icons.collections_bookmark_outlined : Icons.fastfood,
      60,
    );
  }

  Widget _buildCategorySelectors(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_controller.topCategories.length > 1)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _controller.topCategories.length,
              itemBuilder: (context, index) {
                var cat = _controller.topCategories[index];
                bool isSelected = _controller.selectedTopCategory?['id'] == cat['id'];
                return GestureDetector(
                  onTap: () => _controller.selectTopCategory(cat),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected ? [
                        BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                      ] : [],
                    ),
                    child: Center(child: Text(getCategoryName(cat, l10n), style: TextStyle(color: isSelected ? Colors.blue.shade700 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                  ),
                );
              },
            ),
          ),
        if (_controller.selectedTopCategory != null && _controller.selectedTopCategory['id'] != null && _controller.subCategories.length > 1)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _controller.subCategories.length,
              itemBuilder: (context, index) {
                var subCat = _controller.subCategories[index];
                bool isSelected = _controller.selectedSubCategory?['id'] == subCat['id'];
                return GestureDetector(
                  onTap: () => _controller.selectSubCategory(subCat),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected ? [
                        BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                      ] : [],
                    ),
                    child: Center(child: Text(getCategoryName(subCat, l10n), style: TextStyle(color: isSelected ? Colors.blue.shade700 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // +++ DEĞİŞİKLİK BURADA BAŞLIYOR: Kartın yapısı tamamen güncellendi. +++
  Widget _buildMenuItemGrid(AppLocalizations l10n) {
    return Expanded(
      child: _controller.filteredMenuItems.isEmpty
          ? Center(child: Text(l10n.menuNoProductsInCategory, style: TextStyle(color: Colors.white.withOpacity(0.7))))
          : GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220.0,
                mainAxisSpacing: 8.0,
                crossAxisSpacing: 8.0,
                childAspectRatio: 1.1, // Oran güncellendi, deneme yapabilirsiniz.
              ),
              itemCount: _controller.filteredMenuItems.length,
              itemBuilder: (context, index) {
                final item = _controller.filteredMenuItems[index];
                final int currentQuantity = _itemPreQuantities[item.id] ?? 1;

                return Card(
                  color: Colors.white.withOpacity(0.9),
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Üst Kısım: Resim ve Yazılar
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Row(
                            children: [
                              _buildProductImage(item),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    if (item.isCampaignBundle && item.price != null)
                                      Text(
                                        "Fiyat: ${CurrencyFormatter.format(item.price!)}",
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                      )
                                    else if (item.variants != null && item.variants!.isNotEmpty && !item.isCampaignBundle)
                                      Text(l10n.menuVariantsAvailable, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Alt Kısım: Butonlar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        color: Colors.black.withOpacity(0.04),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade300, size: 24),
                                  onPressed: () => _decrementQuantity(item.id),
                                ),
                                Text(
                                  currentQuantity.toString(),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline, color: Colors.green.shade700, size: 24),
                                  onPressed: () => _incrementQuantity(item.id),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart, color: Colors.blueAccent, size: 28),
                              tooltip: l10n.variantSelectionDialogAddToCartButton,
                              onPressed: () {
                                final int quantityToAdd = _itemPreQuantities[item.id] ?? 1;
                                if (item.isCampaignBundle) {
                                  widget.onItemSelected(item, null, [], widget.tableUsers.isNotEmpty ? widget.tableUsers.first : null, quantityToAdd);
                                } else {
                                  bool hasVariants = item.variants != null && item.variants!.isNotEmpty;
                                  if (hasVariants) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => VariantSelectionDialog(
                                        item: item,
                                        tableUsers: widget.tableUsers,
                                        initialQuantity: quantityToAdd,
                                        onItemSelected: (selectedItem, selectedVariant, selectedExtras, tableUser, finalQuantity) {
                                          widget.onItemSelected(selectedItem, selectedVariant, selectedExtras, tableUser, finalQuantity);
                                        },
                                      ),
                                    );
                                  } else {
                                    widget.onItemSelected(item, null, [], widget.tableUsers.isNotEmpty ? widget.tableUsers.first : null, quantityToAdd);
                                  }
                                }
                                if(mounted) {
                                  setState(() {
                                    _itemPreQuantities[item.id] = 1;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
  // +++ DEĞİŞİKLİK BURADA BİTİYOR +++

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCategorySelectors(l10n),
        const SizedBox(height: 6),
        _buildMenuItemGrid(l10n),
      ],
    );
  }
}
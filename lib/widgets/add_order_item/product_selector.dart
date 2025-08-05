// lib/widgets/add_order_item/product_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../controllers/add_order_item_dialog_controller.dart';
import '../../models/menu_item.dart';
import '../../services/api_service.dart'; // Base URL için
import '../shared/image_display.dart'; // Opsiyonel: Ortak image widget'ı için

class ProductSelector extends StatelessWidget {
  final AddOrderItemDialogController controller;
  final ScrollController scrollController;

  const ProductSelector({
    Key? key,
    required this.controller,
    required this.scrollController,
  }) : super(key: key);

  // Görsel URL'sini oluşturur (veya image_helpers'dan alınır)
  String? _getProductImageUrl(MenuItem item) {
    final image = item.image;
    if (image != null && image.isNotEmpty) {
      return image.startsWith('http') ? image : '${ApiService.baseUrl}$image';
    }
    // Kategori görseli fallback'i burada veya Controller'da yapılabilir
    if(item.category != null && item.category is Map && item.category!['image'] != null) {
        final catImage = item.category!['image'];
        if(catImage.toString().isNotEmpty){
            return catImage.toString().startsWith('http') ? catImage : '${ApiService.baseUrl}$catImage';
        }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 110,
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: controller.filteredMenuItems.isEmpty
            ? Center(child: Text(l10n.productSelectorNoProducts, style: const TextStyle(color: Colors.white70)))
            : ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: controller.filteredMenuItems.length,
                itemBuilder: (context, index) {
                  final item = controller.filteredMenuItems[index];
                  final bool isItemSelected = controller.selectedItem?.id == item.id;
                  return GestureDetector(
                    onTap: () => controller.selectItem(item),
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isItemSelected ? const BorderSide(color: Colors.yellowAccent, width: 2) : BorderSide.none
                      ),
                      elevation: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            _buildProductImageWidget(item),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 80,
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // İç helper veya buildImage kullanın
  Widget _buildProductImageWidget(MenuItem item) {
    final url = _getProductImageUrl(item);
    return buildImage(url, Icons.fastfood, 60); // Ortak widget'ı kullan
  }
}
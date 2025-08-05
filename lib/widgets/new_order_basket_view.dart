// lib/widgets/new_order_basket_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart'; // firstWhereOrNull için
import '../models/menu_item.dart';
import '../models/order_item.dart';
import '../services/api_service.dart'; // Base URL için
import '../utils/currency_formatter.dart';

/// Yeni sipariş oluşturulurken sepet içeriğini gösteren widget.
class NewOrderBasketView extends StatelessWidget {
  final List<OrderItem> basket;
  final List<MenuItem> allMenuItems; // Varyant isimleri ve görselleri için
  final Function(OrderItem item) onRemoveItem; // Ürün çıkarmak için callback
  final double totalAmount; // Sepet toplam tutarı

  const NewOrderBasketView({
    Key? key,
    required this.basket,
    required this.allMenuItems, // MenuItem listesini alıyoruz
    required this.onRemoveItem,
    required this.totalAmount,
  }) : super(key: key);


    // Sepet kaleminin görsel URL'sini oluşturur.
  String? _getOrderItemImageUrl(OrderItem orderItem) {
    // Önce orderItem'ın kendi MenuItem objesini bul
    final item = allMenuItems.firstWhereOrNull((m) => m.id == orderItem.menuItem.id);
    if (item == null) return null;

    // Önce varyant görselini dene
    if (orderItem.variant != null && orderItem.variant!.image.isNotEmpty) {
        final variantImage = orderItem.variant!.image;
        return variantImage.startsWith('http') ? variantImage : '${ApiService.baseUrl}$variantImage';
    }

    // Sonra ürün görselini dene
      if (item.image.isNotEmpty) {
        final productImage = item.image;
        return productImage.startsWith('http') ? productImage : '${ApiService.baseUrl}$productImage';
      }

    // Son olarak kategori görselini dene (MenuItem modelinde category Map olarak geldiği için)
    if (item.category != null && item.category is Map && item.category!['image'] != null) {
        final categoryImage = item.category!['image'];
        if (categoryImage.toString().isNotEmpty) {
          return categoryImage.toString().startsWith('http') ? categoryImage : '${ApiService.baseUrl}$categoryImage';
        }
    }

    return null; // Hiçbir görsel bulunamazsa
  }


  // Sepet kaleminin görselini gösteren widget.
  Widget _buildOrderItemImage(OrderItem orderItem) {
      final url = _getOrderItemImageUrl(orderItem);

      if (url != null) {
        return Image.network(url, width: 50, height: 50, fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.fastfood, size: 30), // Hata durumunda ikon göster
        );
      } else {
        return const Icon(Icons.fastfood, size: 30);
      }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column( // Sepet toplamını ve listeyi dikeyde düzenle
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.newOrderBasketTotalLabel(CurrencyFormatter.format(totalAmount)),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 8), // Boşluk ekle
          const Divider(), // Ayırıcı çizgi

          basket.isEmpty
              ? Text(l10n.newOrderBasketEmpty, style: const TextStyle(fontWeight: FontWeight.bold))
              : ListView.builder(
                  shrinkWrap: true, // ListView'in yüksekliğini içeriğine göre ayarla
                  physics: const NeverScrollableScrollPhysics(), // Ana SingleChildScrollView ile birlikte kayması için
                  itemCount: basket.length,
                  itemBuilder: (context, index) {
                    final orderItem = basket[index];
                    // MenuItem'dan variant adını al (eğer varsa)
                    final variantName = orderItem.variant != null ? " (${orderItem.variant!.name})" : "";
                    // Eğer split table ise masa sahibini ekle
                    final tableUserDisplay = orderItem.tableUser != null ? " - ${orderItem.tableUser}" : "";

                    // Ekstraları listele
                    final extrasDisplay = (orderItem.extras ?? []).map((e) => "${e.name} x${e.quantity}").join(', ');


                    return ListTile(
                      leading: _buildOrderItemImage(orderItem), // Görseli göster
                      title: Text(
                        "${orderItem.menuItem.name}$variantName$tableUserDisplay",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column( // Alt başlıkta adet ve ekstraları göster
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.newOrderBasketQuantity(orderItem.quantity.toString())),
                            if(extrasDisplay.isNotEmpty)
                              Text(l10n.newOrderBasketExtras(extrasDisplay)),
                          ],
                        ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          onRemoveItem(orderItem); // Callback'i çağır
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
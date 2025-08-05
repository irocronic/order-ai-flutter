// lib/widgets/order_item_widget.dart

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // YENİ: Yerelleştirme importu
import '../models/menu_item.dart';
import '../services/api_service.dart';

/// Tek bir sipariş kalemini görüntüleyen ve onunla etkileşim sağlayan widget.
class OrderItemWidget extends StatelessWidget {
  final dynamic item;
  final String token;
  final List<MenuItem> allMenuItems;
  final bool isLoading;
  final VoidCallback onDelete;
  final VoidCallback onDeliver;
  final VoidCallback onAddExtra;

  const OrderItemWidget({
    Key? key,
    required this.item,
    required this.token,
    required this.allMenuItems,
    required this.isLoading,
    required this.onDelete,
    required this.onDeliver,
    required this.onAddExtra,
  }) : super(key: key);

  // Bu metotlarda değişiklik yok
  double _itemTotal(dynamic item) {
    double mainPrice = 0;
    if (item['variantId'] != null && allMenuItems.isNotEmpty) {
      final product = allMenuItems.firstWhereOrNull((m) => m.id == item['menu_item']['id']);
      final variant = product?.variants?.firstWhereOrNull((v) => v.id == item['variantId']);
      mainPrice = variant?.price ?? 0.0;
    } else if (item['menu_item'] != null && item['menu_item']['price'] != null) {
      try {
        mainPrice = double.parse(item['menu_item']['price'].toString());
      } catch (_) {
        mainPrice = 0;
      }
    }

    double extrasTotal = 0;
    if (item['extras'] != null) {
      for (var extraJson in item['extras']) {
        try {
          double extraPrice = double.parse(extraJson['price']?.toString() ?? '0');
          int extraQuantity = extraJson['quantity'] ?? 0;
          extrasTotal += extraPrice * extraQuantity;
        } catch (_) {}
      }
    }

    int quantity = item['quantity'] ?? 0;
    return (mainPrice + extrasTotal) * quantity;
  }

  String? _getProductImageUrl(Map<String, dynamic> orderItem) {
    final productImage = orderItem['menu_item']['image'] ?? '';
    if (productImage.toString().isNotEmpty) {
      return productImage.toString().startsWith('http')
          ? productImage
          : '${ApiService.baseUrl}$productImage';
    }
    return null;
  }

  String? _getVariantImageUrl(Map<String, dynamic> orderItem) {
    if (item['variantId'] == null) return null;
    final product = allMenuItems.firstWhereOrNull((m) => m.id == item['menu_item']['id']);
    final variant = product?.variants?.firstWhereOrNull((v) => v.id == item['variantId']);
    final variantImage = variant?.image ?? '';
    if (variantImage.isNotEmpty) {
      return variantImage.startsWith('http') ? variantImage : '${ApiService.baseUrl}$variantImage';
    }
    return null;
  }

  String? _getCategoryImageUrl(Map<String, dynamic> orderItem) {
    if (orderItem['menu_item']['category'] != null) {
      final cat = orderItem['menu_item']['category'];
      if (cat is Map<String, dynamic>) {
        final catImage = cat['image'] ?? '';
        if (catImage.toString().isNotEmpty) {
          return catImage.toString().startsWith('http') ? catImage : '${ApiService.baseUrl}$catImage';
        }
      }
    }
    return null;
  }

  Widget _buildOrderItemImages(Map<String, dynamic> orderItem) {
    String? productUrl = _getProductImageUrl(orderItem);
    String? variantUrl = _getVariantImageUrl(orderItem);

    if (productUrl == null) {
      productUrl = _getCategoryImageUrl(orderItem);
    }
    if (variantUrl == null) {
      variantUrl = _getCategoryImageUrl(orderItem);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: productUrl != null
                ? DecorationImage(image: NetworkImage(productUrl), fit: BoxFit.cover)
                : null,
            color: productUrl == null ? Colors.grey[300] : null,
          ),
          child: productUrl == null ? const Icon(Icons.fastfood, size: 30) : null,
        ),
        const SizedBox(width: 4),
        if (variantUrl != null)
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
              image: DecorationImage(image: NetworkImage(variantUrl), fit: BoxFit.cover),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // YENİ: l10n nesnesi burada alınıyor
    final l10n = AppLocalizations.of(context)!;
    final extras = (item['extras'] as List?) ?? [];
    final itemTotal = _itemTotal(item);
    String tableUser = "";
    if (item['table_user'] != null &&
        item['table_user'].toString().trim().isNotEmpty) {
      tableUser = item['table_user'];
    }
    final bool isDelivered = item['delivered'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withOpacity(0.8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderItemImages(item),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['menu_item']['name'] +
                        (item['variantId'] != null && allMenuItems.isNotEmpty
                            ? ' (${allMenuItems.firstWhereOrNull((m) => m.id == item['menu_item']['id'])?.variants?.firstWhereOrNull((v) => v.id == item['variantId'])?.name ?? item['variantId']})'
                            : ''),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // GÜNCELLENDİ
                  Text(l10n.orderItemQuantity(item['quantity'].toString())),
                  if (extras.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    // GÜNCELLENDİ
                    Text(l10n.orderItemExtrasLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...extras.map((e) {
                      // GÜNCELLENDİ
                      return Text('• ${e['variant_name'] ?? l10n.orderItemUnknownExtra} x${e['quantity']}');
                    }),
                  ],
                  const SizedBox(height: 8),
                  // GÜNCELLENDİ
                  Text(l10n.orderItemLineTotal(itemTotal.toStringAsFixed(2), l10n.currencySymbol),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (tableUser.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        // GÜNCELLENDİ
                        l10n.orderItemTableOwner(tableUser),
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (item['delivered'] != true)
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : onDeliver,
                      icon: const Icon(Icons.check_circle),
                      // GÜNCELLENDİ
                      label: Text(l10n.orderItemButtonDeliver),
                    )
                  else
                    // GÜNCELLENDİ
                    Text(l10n.orderItemStatusDelivered, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item['variantId'] != null && !(item['delivered'] == true))
                  IconButton(
                    icon: const Icon(Icons.add_box),
                    // GÜNCELLENDİ
                    tooltip: l10n.orderItemTooltipAddExtra,
                    onPressed: isLoading ? null : onAddExtra,
                  ),
                if (item['delivered'] != true)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    // GÜNCELLENDİ
                    tooltip: l10n.orderItemTooltipRemove,
                    onPressed: isLoading ? null : onDelete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
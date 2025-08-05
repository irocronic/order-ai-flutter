// lib/widgets/new_order_basket_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/order_item.dart';

/// Yeni sipariş ekranı için sepet bölümünü görüntüleyen widget.
class NewOrderBasketSection extends StatelessWidget {
  final List<OrderItem> basketItems;
  final double totalAmount;
  final Function(int index) onRemoveItem;

  const NewOrderBasketSection({
    Key? key,
    required this.basketItems,
    required this.totalAmount,
    required this.onRemoveItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.basketTitle,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (basketItems.isEmpty)
            Text(
              l10n.newOrderBasketEmpty, // reused key
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
              textAlign: TextAlign.center,
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Ana ekranla birlikte kaydırılacak
              itemCount: basketItems.length,
              itemBuilder: (context, index) {
                final orderItem = basketItems[index];
                // Sepetteki ürünlerin görüntülenmesi
                return ListTile(
                  dense: true, // Daha kompakt görünüm
                  title: Text(
                    orderItem.menuItem.name +
                        (orderItem.variant != null
                            ? " (${orderItem.variant!.name})"
                            : "") +
                        (orderItem.tableUser != null
                            ? " - ${orderItem.tableUser}"
                            : ""),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.newOrderBasketQuantity(orderItem.quantity.toString()), style: const TextStyle(fontSize: 12)), // reused key
                        if (orderItem.extras != null && orderItem.extras!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              l10n.newOrderBasketExtras(orderItem.extras!.map((e) => '${e.name} x${e.quantity}').join(', ')), // reused key
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                      ],
                    ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () => onRemoveItem(index),
                    tooltip: l10n.removeFromBasketTooltip,
                  ),
                );
              },
            ),
          const Divider(color: Colors.black54),
          Text(
            l10n.newOrderBasketTotalLabel(totalAmount.toStringAsFixed(2), l10n.currencySymbol),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}
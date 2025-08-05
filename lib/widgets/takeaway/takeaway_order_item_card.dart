// lib/widgets/takeaway/takeaway_order_item_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../models/order_item.dart';
import '../../services/api_service.dart';
import '../../utils/currency_formatter.dart';
import '../shared/image_display.dart';

class TakeawayOrderItemCard extends StatelessWidget {
  final OrderItem item;
  final String token;
  final List<MenuItem> allMenuItems;
  final bool isLoading;
  final VoidCallback onDelete;
  final VoidCallback onDeliver;
  final VoidCallback onAddExtra;

  const TakeawayOrderItemCard({
    Key? key,
    required this.item,
    required this.token,
    required this.allMenuItems,
    required this.isLoading,
    required this.onDelete,
    required this.onDeliver,
    required this.onAddExtra,
  }) : super(key: key);

  double _calculateLineItemTotal() {
    return item.price * item.quantity;
  }

  Widget _buildOrderItemImages() {
    final menuItem = item.menuItem;
    String? productUrl;
    String? categoryImageUrl;
    String? variantUrl;

    if (item.variant?.image.isNotEmpty ?? false) {
      variantUrl = item.variant!.image.startsWith('http')
          ? item.variant!.image
          : '${ApiService.baseUrl}${item.variant!.image}';
    }

    if (menuItem.image.isNotEmpty) {
      productUrl = menuItem.image.startsWith('http')
          ? menuItem.image
          : '${ApiService.baseUrl}${menuItem.image}';
    }

    if (menuItem.category is Map && menuItem.category!['image'] != null) {
      final catImage = menuItem.category!['image'];
      if (catImage.toString().isNotEmpty) {
        categoryImageUrl = catImage.toString().startsWith('http')
            ? catImage
            : '${ApiService.baseUrl}$catImage';
      }
    }

    final String displayImageUrl = variantUrl ?? productUrl ?? categoryImageUrl ?? '';

    return buildImage(
      displayImageUrl.isNotEmpty ? displayImageUrl : null,
      menuItem.isCampaignBundle
          ? Icons.collections_bookmark_outlined
          : Icons.fastfood_outlined,
      60,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final extras = item.extras ?? [];
    final itemLineTotal = _calculateLineItemTotal();
    final bool isDelivered = item.waiterPickedUpAt != null;
    final bool isCampaign = item.menuItem.isCampaignBundle;
    final String variantNameDisplay =
        (item.variant?.name != null && item.variant!.name.isNotEmpty)
            ? ' (${item.variant!.name})'
            : '';

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white.withOpacity(isDelivered ? 0.7 : 0.85),
      elevation: isDelivered ? 2 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderItemImages(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.menuItem.name + variantNameDisplay,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      decoration: isDelivered ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // +++ DEĞİŞİKLİK BURADA BAŞLIYOR +++
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Text(l10n.newOrderBasketQuantity(item.quantity.toString()), style: TextStyle(decoration: isDelivered ? TextDecoration.lineThrough : null, fontSize: 13)),
                  if (extras.isNotEmpty && !isCampaign) ...[
                    const SizedBox(height: 4),
                    Text(l10n.extrasLabel,
                        style: TextStyle(fontWeight: FontWeight.w500, decoration: isDelivered ? TextDecoration.lineThrough : null, fontSize: 13)),
                    ...extras.map((e) {
                      return Text(
                        '• ${e.name} x${e.quantity}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, decoration: isDelivered ? TextDecoration.lineThrough : null),
                      );
                    }),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    l10n.lineItemTotal(CurrencyFormatter.format(itemLineTotal), ''),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, decoration: isDelivered ? TextDecoration.lineThrough : null)
                  ),
                ],
              ),
            ),
          ),
          // +++ DEĞİŞİKLİK BİTİYOR +++

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (!isDelivered)
                   Expanded(
                     child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade800,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isLoading ? null : onDeliver,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(l10n.buttonDeliver),
                      ),
                   )
                 else
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.symmetric(vertical: 12.0),
                       child: Text(l10n.statusDelivered,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                     ),
                   ),
                if(!isDelivered) ...[
                   SizedBox(
                      height: 30,
                      child: VerticalDivider(color: Colors.grey.shade400, width: 1),
                   ),
                   IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      tooltip: l10n.buttonRemove,
                      onPressed: isLoading ? null : onDelete,
                   )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}
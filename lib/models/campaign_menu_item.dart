// lib/models/campaign_menu_item.dart

class CampaignMenuItem {
  final int? id; // Backend'den gelirken dolu, gönderirken null olabilir
  final int menuItemId;
  final String? menuItemName; // Okuma için
  final int? variantId;
  final String? variantName; // Okuma için
  final int quantity;
  final double? originalPrice; // Okuma için

  CampaignMenuItem({
    this.id,
    required this.menuItemId,
    this.menuItemName,
    this.variantId,
    this.variantName,
    required this.quantity,
    this.originalPrice,
  });

  factory CampaignMenuItem.fromJson(Map<String, dynamic> json) {
    return CampaignMenuItem(
      id: json['id'] as int?,
      menuItemId: json['menu_item'] ?? 0,
      menuItemName: json['menu_item_name'],
      variantId: json['variant'] as int?,
      variantName: json['variant_name'],
      quantity: json['quantity'] ?? 1,
      originalPrice: double.tryParse(json['original_price']?.toString() ?? '0.0'),
    );
  }

  // Backend'e göndermek için (create/update)
  Map<String, dynamic> toJsonForSubmit() {
    return {
      'menu_item': menuItemId,
      if (variantId != null) 'variant': variantId,
      'quantity': quantity,
    };
  }
}
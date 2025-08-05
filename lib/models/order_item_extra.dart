// lib/models/order_item_extra.dart
class OrderItemExtra {
  final int id;
  final int variant; // MenuItemVariant id
  final String name;
  final double price;
  int quantity;

  OrderItemExtra({
    required this.id,
    required this.variant,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  factory OrderItemExtra.fromJson(Map<String, dynamic> json) {
    return OrderItemExtra(
      id: json['id'] ?? 0,
      variant: json['variant'] ?? 0,
      // Backend'den gelen 'variant_name' ve 'variant_price' alanlarını da yakala
      name: json['variant_name'] ?? json['name'] ?? 'Bilinmeyen Ekstra',
      price: double.tryParse(json['variant_price']?.toString() ?? json['price']?.toString() ?? '0.0') ?? 0.0,
      quantity: json['quantity'] ?? 1,
    );
  }

  // Backend'e sipariş oluştururken veya güncellerken gönderilecek format
  Map<String, dynamic> toJson() {
    return {
      'variant': variant,
      'quantity': quantity,
    };
  }

  Map<String, dynamic> toJsonForCard() {
    return {
      'id': id,
      'variant': variant,
      'variant_name': name,
      'variant_price': price,
      'quantity': quantity,
    };
  }
}
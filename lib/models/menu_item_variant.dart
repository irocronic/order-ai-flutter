// lib/models/menu_item_variant.dart
class MenuItemVariant {
  final int id;
  final int menuItem; // Menü öğesi ID'si
  final String name;
  final double price;
  final bool isExtra; // Ekstra ürün olup olmadığını belirtir
  final String image; // Yeni eklenen alan

  MenuItemVariant({
    required this.id,
    required this.menuItem,
    required this.name,
    required this.price,
    this.isExtra = false,
    this.image = '',
  });

  factory MenuItemVariant.fromJson(Map<String, dynamic> json) {
    return MenuItemVariant(
      id: json['id'] as int? ?? 0,
      menuItem: json['menu_item'] as int? ?? 0,
      name: json['name'] ?? 'Bilinmeyen Varyant', // İsim için de fallback eklendi
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      isExtra: json['is_extra'] as bool? ?? false,
      image: json['image'] as String? ?? '', // Görsel alanı
    );
  }
}
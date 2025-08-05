// lib/models/menu_item.dart

import 'package:equatable/equatable.dart';
import 'menu_item_variant.dart';

// DÜZELTME 1: Sınıf artık 'Equatable' sınıfından kalıtım alıyor.
class MenuItem extends Equatable {
  final int id;
  final String name;
  final String image;
  final String description;
  final Map<String, dynamic>? category;
  final List<MenuItemVariant>? variants;
  final bool isCampaignBundle;
  final double? price;
  // YENİ: KDV Oranı alanı eklendi
  final double? kdvRate;

  const MenuItem({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
    this.category,
    this.variants,
    this.isCampaignBundle = false,
    this.price,
    this.kdvRate, // YENİ: Constructor'a eklendi
  });

  // DÜZELTME 2: 'props' listesi eklendi.
  // Bu, iki MenuItem nesnesinin eşit olup olmadığını kontrol etmek için sadece 'id' alanına bakılmasını sağlar.
  // Dropdown hatasının çözümü budur.
  @override
  List<Object?> get props => [id];

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? category;
    if (json['category'] != null) {
      if (json['category'] is int) {
        category = {'id': json['category'], 'name': 'Bilinmiyor'}; // Geçici çözüm
      } else if (json['category'] is Map<String, dynamic>) {
        category = json['category'] as Map<String, dynamic>;
      }
    }

    List<MenuItemVariant>? variants;
    if (json['variants'] != null && json['variants'] is List) {
      variants = (json['variants'] as List)
          .map((variantJson) => MenuItemVariant.fromJson(variantJson as Map<String, dynamic>))
          .toList();
    }

    bool isCampaign = json['is_campaign_bundle'] as bool? ?? false;
    double? campaignPrice;
    if (isCampaign && json['price'] != null) {
      campaignPrice = double.tryParse(json['price'].toString());
    }

    return MenuItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      description: json['description'] ?? '',
      category: category,
      variants: variants,
      isCampaignBundle: isCampaign,
      price: campaignPrice,
      kdvRate: double.tryParse(json['kdv_rate']?.toString() ?? '10.0'),
    );
  }
}
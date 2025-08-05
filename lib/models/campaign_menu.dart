// lib/models/campaign_menu.dart

import 'campaign_menu_item.dart';

class CampaignMenu {
  final int id;
  final int businessId;
  final String name;
  final String? description;
  final String? image; // Firebase URL
  final double campaignPrice;
  final List<CampaignMenuItem> campaignItems;
  final bool isActive;
  final String? startDate; // ISO formatında tarih
  final String? endDate;   // ISO formatında tarih
  final String? createdAt;
  final String? updatedAt;
  final double? totalNormalPrice; // Backend'den hesaplanmış gelebilir
  final int? bundleMenuItemId; // İlişkili MenuItem ID'si (sipariş için)

  CampaignMenu({
    required this.id,
    required this.businessId,
    required this.name,
    this.description,
    this.image,
    required this.campaignPrice,
    required this.campaignItems,
    required this.isActive,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
    this.totalNormalPrice,
    this.bundleMenuItemId,
  });

  factory CampaignMenu.fromJson(Map<String, dynamic> json) {
    return CampaignMenu(
      id: json['id'] ?? 0,
      businessId: json['business'] ?? 0,
      name: json['name'] ?? 'Bilinmeyen Kampanya',
      description: json['description'],
      image: json['image'],
      campaignPrice: double.tryParse(json['campaign_price']?.toString() ?? '0.0') ?? 0.0,
      campaignItems: (json['campaign_items'] as List<dynamic>?)
              ?.map((itemJson) => CampaignMenuItem.fromJson(itemJson as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['is_active'] ?? false,
      startDate: json['start_date'],
      endDate: json['end_date'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      totalNormalPrice: double.tryParse(json['total_normal_price']?.toString() ?? '0.0'),
      bundleMenuItemId: json['bundle_menu_item_id'] as int?,
    );
  }

  // Backend'e göndermek için (create/update)
  Map<String, dynamic> toJsonForSubmit() {
    return {
      'name': name,
      'description': description,
      'image': image, // Yeni resim seçildiyse bu güncellenmeli
      'campaign_price': campaignPrice.toStringAsFixed(2),
      'is_active': isActive,
      if (startDate != null && startDate!.isNotEmpty) 'start_date': startDate,
      if (endDate != null && endDate!.isNotEmpty) 'end_date': endDate,
      'campaign_items': campaignItems.map((item) => item.toJsonForSubmit()).toList(),
    };
  }
}
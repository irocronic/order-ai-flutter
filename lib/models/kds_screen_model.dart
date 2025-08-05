// lib/models/kds_screen_model.dart

import 'package:flutter/foundation.dart'; // debugPrint için (opsiyonel)

class KdsScreenModel {
  final int id;
  final int businessId;
  final String name;
  final String slug;
  final String? description;
  final bool isActive;
  final String? createdAt; // ISO 8601 formatında tarih string'i
  final String? updatedAt; // ISO 8601 formatında tarih string'i

  KdsScreenModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.slug,
    this.description,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory KdsScreenModel.fromJson(Map<String, dynamic> json) {
    return KdsScreenModel(
      id: json['id'] as int? ?? 0,
      // Backend 'business' veya 'business_id' gönderebilir, ikisini de kontrol edelim.
      businessId: json['business'] as int? ?? json['business_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Bilinmeyen KDS Ekranı',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  /// Backend'e yeni KDS ekranı oluşturmak veya güncellemek için JSON oluşturur.
  /// `slug` genellikle backend tarafından otomatik oluşturulduğu için gönderilmez.
  Map<String, dynamic> toJsonForSubmit() {
    final Map<String, dynamic> data = {
      'name': name,
      'is_active': isActive,
      // businessId genellikle URL üzerinden veya ViewSet'te otomatik olarak ayarlanır,
      // eğer payload'da göndermek gerekiyorsa buraya eklenebilir:
      // 'business': businessId,
    };
    if (description != null) {
      data['description'] = description;
    }
    return data;
  }

  @override
  String toString() {
    return 'KdsScreenModel(id: $id, name: "$name", slug: "$slug", businessId: $businessId, isActive: $isActive)';
  }
}
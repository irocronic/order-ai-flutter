// lib/models/stock.dart

import 'package:flutter/foundation.dart';

class Stock {
  final int id;
  final int variantId;
  final String variantName;
  final String productName;
  final int quantity;
  final DateTime? lastUpdated;
  final bool trackStock;      // YENİ
  final int? alertThreshold;  // YENİ

  Stock({
    required this.id,
    required this.variantId,
    required this.variantName,
    required this.productName,
    required this.quantity,
    this.lastUpdated,
    required this.trackStock,
    this.alertThreshold,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      id: json['id'] ?? 0,
      variantId: json['variant'] ?? 0,
      variantName: json['variant_name'] ?? 'Bilinmeyen Varyant',
      productName: json['product_name'] ?? 'Bilinmeyen Ürün',
      quantity: json['quantity'] as int? ?? 0,
      lastUpdated: json['last_updated'] != null ? DateTime.tryParse(json['last_updated']) : null,
      trackStock: json['track_stock'] as bool? ?? true,
      alertThreshold: json['alert_threshold'] as int?,
    );
  }
  String get variantFullName => '$productName ($variantName)';
}
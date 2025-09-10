// lib/models/ingredient.dart

class Ingredient {
  final int id;
  final String name;
  final double stockQuantity;
  final String unitAbbreviation;
  final double? alertThreshold;
  // +++ YENİ ALAN +++
  final bool lowStockNotificationSent;
  final bool trackStock; // --- BU SATIR EKLENDİ ---

  Ingredient({
    required this.id,
    required this.name,
    required this.stockQuantity,
    required this.unitAbbreviation,
    this.alertThreshold,
    // +++ CONSTRUCTOR'A EKLENDİ +++
    this.lowStockNotificationSent = false,
    required this.trackStock, // --- BU SATIR EKLENDİ ---
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'],
      name: json['name'],
      stockQuantity: double.tryParse(json['stock_quantity'].toString()) ?? 0.0,
      unitAbbreviation: json['unit']?['abbreviation'] ?? 'Birim',
      alertThreshold: json['alert_threshold'] != null ? double.tryParse(json['alert_threshold'].toString()) : null,
      // +++ JSON'DAN OKUMA EKLENDİ +++
      lowStockNotificationSent: json['low_stock_notification_sent'] as bool? ?? false,
      trackStock: json['track_stock'] as bool? ?? true, // --- BU SATIR EKLENDİ ---
    );
  }
}
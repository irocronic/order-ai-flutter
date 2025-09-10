// lib/models/ingredient.dart

class Ingredient {
  final int id;
  final String name;
  final double stockQuantity;
  final String unitAbbreviation;
  final double? alertThreshold;

  Ingredient({
    required this.id,
    required this.name,
    required this.stockQuantity,
    required this.unitAbbreviation,
    this.alertThreshold,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'],
      name: json['name'],
      stockQuantity: double.tryParse(json['stock_quantity'].toString()) ?? 0.0,
      unitAbbreviation: json['unit']?['abbreviation'] ?? 'Birim',
      alertThreshold: json['alert_threshold'] != null ? double.tryParse(json['alert_threshold'].toString()) : null,
    );
  }
}
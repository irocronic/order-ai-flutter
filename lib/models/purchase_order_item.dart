// lib/models/purchase_order_item.dart - ALTERNATİF ÇÖZÜM

class PurchaseOrderItem {
  final int? id;
  final int ingredientId;
  final String ingredientName;
  final String unitAbbreviation;
  double quantity;
  double unitPrice;
  final double? alertThreshold;

  PurchaseOrderItem({
    this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.unitAbbreviation,
    required this.quantity,
    required this.unitPrice,
    this.alertThreshold,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] as int?,
      ingredientId: json['ingredient'] as int? ?? 0,
      ingredientName: json['ingredient_name'] as String? ?? 'Bilinmeyen Malzeme',
      unitAbbreviation: json['unit_abbreviation'] as String? ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0.0') ?? 0.0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0.0') ?? 0.0,
      alertThreshold: json['alert_threshold'] != null 
          ? double.tryParse(json['alert_threshold']?.toString() ?? '0.0') 
          : null,
    );
  }

  Map<String, dynamic> toJsonForSubmit() {
    final Map<String, dynamic> json = {
      'ingredient': ingredientId,
      'quantity': quantity,
      'unit_price': unitPrice.toStringAsFixed(2),
    };
    
    // *** GÜVENLI ÇÖZÜM: Ayrı değişken kullanarak ***
    final threshold = alertThreshold;
    if (threshold != null) {
      json['alert_threshold'] = threshold;
    }
    
    return json;
  }
}
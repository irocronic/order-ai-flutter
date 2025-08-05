// lib/models/stock_movement.dart

class StockMovement {
  final int id;
  final int stockId; // Stock modelinin ID'si
  final int variantId;
  final String variantName;
  final String productName;
  final String movementType; // 'ADDITION', 'SALE', 'RETURN' etc.
  final String movementTypeDisplay; // 'Stok Girişi', 'Satış' etc.
  final int quantityChange;
  final int quantityBefore;
  final int quantityAfter;
  final DateTime timestamp;
  final int? userId;
  final String? userUsername;
  final String? description;
  final int? relatedOrderId;

  StockMovement({
    required this.id,
    required this.stockId,
    required this.variantId,
    required this.variantName,
    required this.productName,
    required this.movementType,
    required this.movementTypeDisplay,
    required this.quantityChange,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.timestamp,
    this.userId,
    this.userUsername,
    this.description,
    this.relatedOrderId,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    return StockMovement(
      id: json['id'] ?? 0,
      stockId: json['stock'] ?? 0, // Django'dan 'stock' olarak gelir (ID)
      variantId: json['variant'] ?? 0, // Django'dan 'variant' olarak gelir (ID)
      variantName: json['variant_name'] ?? 'Bilinmiyor',
      productName: json['product_name'] ?? 'Bilinmiyor',
      movementType: json['movement_type'] ?? 'UNKNOWN',
      movementTypeDisplay: json['movement_type_display'] ?? 'Bilinmeyen Hareket',
      quantityChange: json['quantity_change'] ?? 0,
      quantityBefore: json['quantity_before'] ?? 0,
      quantityAfter: json['quantity_after'] ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      userId: json['user'], // Django'dan user ID olarak gelir
      userUsername: json['user_username'],
      description: json['description'],
      relatedOrderId: json['related_order'], // Django'dan order ID olarak gelebilir
    );
  }
}
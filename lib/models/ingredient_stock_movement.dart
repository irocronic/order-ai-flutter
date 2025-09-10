// lib/models/ingredient_stock_movement.dart

class IngredientStockMovement {
  final int id;
  final String movementTypeDisplay;
  final double quantityChange;
  final double quantityBefore;
  final double quantityAfter;
  final DateTime timestamp;
  final String? userUsername;
  final String? description;

  IngredientStockMovement({
    required this.id,
    required this.movementTypeDisplay,
    required this.quantityChange,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.timestamp,
    this.userUsername,
    this.description,
  });

  factory IngredientStockMovement.fromJson(Map<String, dynamic> json) {
    return IngredientStockMovement(
      id: json['id'] ?? 0,
      movementTypeDisplay: json['movement_type_display'] ?? 'Bilinmeyen',
      quantityChange: double.tryParse(json['quantity_change'].toString()) ?? 0.0,
      quantityBefore: double.tryParse(json['quantity_before'].toString()) ?? 0.0,
      quantityAfter: double.tryParse(json['quantity_after'].toString()) ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '')?.toLocal() ?? DateTime.now(),
      userUsername: json['user_username'],
      description: json['description'],
    );
  }
}
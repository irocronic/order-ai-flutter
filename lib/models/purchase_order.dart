// lib/models/purchase_order.dart

import 'purchase_order_item.dart';

class PurchaseOrder {
  final int id;
  final int supplierId;
  final String supplierName;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double totalCost;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.totalCost,
    required this.items,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as int? ?? 0,
      supplierId: json['supplier'] as int? ?? 0,
      supplierName: json['supplier_name'] as String? ?? 'Bilinmiyor',
      status: json['status'] as String? ?? 'unknown',
      createdAt: DateTime.tryParse(json['created_at'] ?? '')?.toLocal() ?? DateTime.now(),
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'])?.toLocal() : null,
      
      // === DÜZELTME: Hem total_cost hem total_amount desteklenmesi ===
      totalCost: _parseTotalCost(json),
      
      items: (json['items'] as List<dynamic>?)
              ?.map((itemJson) => PurchaseOrderItem.fromJson(itemJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // === YENİ: Güvenli total cost parsing metodu ===
  static double _parseTotalCost(Map<String, dynamic> json) {
    // Önce total_amount'u dene (backend'den gelen)
    if (json['total_amount'] != null) {
      final totalAmount = double.tryParse(json['total_amount']?.toString() ?? '0.0');
      if (totalAmount != null && totalAmount > 0) {
        return totalAmount;
      }
    }
    
    // Sonra total_cost'u dene (alternatif)
    if (json['total_cost'] != null) {
      final totalCost = double.tryParse(json['total_cost']?.toString() ?? '0.0');
      if (totalCost != null && totalCost > 0) {
        return totalCost;
      }
    }
    
    // Her ikisi de yoksa 0.0 döndür
    return 0.0;
  }
  
  // === YENİ: Debug için toString metodu ===
  @override
  String toString() {
    return 'PurchaseOrder{id: $id, supplier: $supplierName, status: $status, totalCost: $totalCost, items: ${items.length}}';
  }
}
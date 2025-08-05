// lib/models/credit_payment_details.dart
class CreditPaymentDetails {
  final int id;
  final int order; // İlişkili siparişin ID'si
  final String? customerName;
  final String? customerPhone;
  final String? notes;
  final DateTime createdAt;
  final DateTime? paidAt; // Ödemenin kapatıldığı tarih (nullable)

  CreditPaymentDetails({
    required this.id,
    required this.order,
    this.customerName,
    this.customerPhone,
    this.notes,
    required this.createdAt,
    this.paidAt,
  });

  factory CreditPaymentDetails.fromJson(Map<String, dynamic> json) {
    return CreditPaymentDetails(
      id: json['id'] ?? 0,
      order: json['order'] ?? 0,
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    );
  }
}

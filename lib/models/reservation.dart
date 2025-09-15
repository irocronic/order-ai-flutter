// lib/models/reservation.dart (YENİ DOSYA)

class Reservation {
  final int id;
  final int businessId;
  final int tableId;
  final int tableNumber;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final DateTime reservationTime;
  final int partySize;
  final String? notes;
  final String status;
  final String statusDisplay;
  final DateTime createdAt;

  Reservation({
    required this.id,
    required this.businessId,
    required this.tableId,
    required this.tableNumber,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.reservationTime,
    required this.partySize,
    this.notes,
    required this.status,
    required this.statusDisplay,
    required this.createdAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as int,
      businessId: json['business'] as int,
      tableId: json['table'] as int,
      tableNumber: json['table_number'] as int? ?? 0,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      customerEmail: json['customer_email'] as String?,
      reservationTime: DateTime.parse(json['reservation_time'] as String).toLocal(),
      partySize: json['party_size'] as int,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      statusDisplay: json['status_display'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
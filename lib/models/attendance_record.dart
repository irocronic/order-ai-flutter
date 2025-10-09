// lib/models/attendance_record.dart
enum AttendanceType { checkIn, checkOut }

class AttendanceRecord {
  final int? id;
  final int userId;
  final int businessId;
  final AttendanceType type;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final int? checkInLocationId;
  final String? notes;
  final String? qrCodeData;
  final bool isManualEntry;

  AttendanceRecord({
    this.id,
    required this.userId,
    required this.businessId,
    required this.type,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.checkInLocationId,
    this.notes,
    this.qrCodeData,
    this.isManualEntry = false,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int?,
      userId: json['user'] as int,
      businessId: json['business'] as int,
      type: json['type'] == 'check_in' ? AttendanceType.checkIn : AttendanceType.checkOut,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      checkInLocationId: json['check_in_location'] as int?,
      notes: json['notes'] as String?,
      qrCodeData: json['qr_code_data'] as String?,
      isManualEntry: json['is_manual_entry'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user': userId,
      'business': businessId,
      'type': type == AttendanceType.checkIn ? 'check_in' : 'check_out',
      'timestamp': timestamp.toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (checkInLocationId != null) 'check_in_location': checkInLocationId,
      if (notes != null) 'notes': notes,
      if (qrCodeData != null) 'qr_code_data': qrCodeData,
      'is_manual_entry': isManualEntry,
    };
  }
}
// lib/models/check_in_location.dart
class CheckInLocation {
  final int id;
  final int businessId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  CheckInLocation({
    required this.id,
    required this.businessId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory CheckInLocation.fromJson(Map<String, dynamic> json) {
    return CheckInLocation(
      id: json['id'] as int,
      businessId: json['business'] as int,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business': businessId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
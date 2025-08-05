// lib/models/staff_performance.dart

import 'staff_permission_keys.dart';

class StaffPerformance {
  final int staffId;
  final String username;
  final String? firstName;
  final String? lastName;
  final int orderCount;
  final double totalTurnover;
  final int preparedItemCount;
  final List<String> staffPermissions;
  final List<String> accessibleKdsNames;
  final String? profileImageUrl;

  StaffPerformance({
    required this.staffId,
    required this.username,
    this.firstName,
    this.lastName,
    required this.orderCount,
    required this.totalTurnover,
    required this.preparedItemCount,
    required this.staffPermissions,
    required this.accessibleKdsNames,
    this.profileImageUrl,
  });

  factory StaffPerformance.fromJson(Map<String, dynamic> json) {
    return StaffPerformance(
      staffId: json['staff_id'] ?? 0,
      username: json['username'] ?? 'Bilinmiyor',
      firstName: json['first_name'],
      lastName: json['last_name'],
      orderCount: json['order_count'] ?? 0,
      totalTurnover: (json['total_turnover'] is String)
          ? (double.tryParse(json['total_turnover']) ?? 0.0)
          : ((json['total_turnover'] as num?)?.toDouble() ?? 0.0),
      preparedItemCount: json['prepared_item_count'] as int? ?? 0,
      staffPermissions: (json['staff_permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      accessibleKdsNames: (json['accessible_kds_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      profileImageUrl: json['profile_image_url'],
    );
  }

  String get fullName {
    String name = '';
    if (firstName != null && firstName!.isNotEmpty) {
      name += firstName!;
    }
    if (lastName != null && lastName!.isNotEmpty) {
      if (name.isNotEmpty) name += ' ';
      name += lastName!;
    }
    return name.isNotEmpty ? name : username;
  }

  bool get canTakeOrders => staffPermissions.contains(PermissionKeys.takeOrders);
  bool get canManageKds => staffPermissions.contains(PermissionKeys.manageKds);
  bool get hasKdsAccess => accessibleKdsNames.isNotEmpty;
}
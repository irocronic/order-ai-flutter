// lib/models/order.dart

import 'order_item.dart';

enum OrderStatus {
  pendingApproval, // pending_approval
  approved,        // approved
  preparing,       // preparing
  readyForPickup,  // ready_for_pickup
  readyForDelivery,// ready_for_delivery
  rejected,        // rejected
  completed,       // completed
  cancelled,       // cancelled
  pendingSync,     // YENİ: Çevrimdışı siparişler için
  unknown,         // Bilinmeyen veya eşleşmeyen durumlar için
}

// Backend'den gelen string status değerini OrderStatus enum'una çevirir.
OrderStatus statusFromString(String? statusStr) {
  switch (statusStr) {
    case 'pending_approval':
      return OrderStatus.pendingApproval;
    case 'approved':
      return OrderStatus.approved;
    case 'preparing':
      return OrderStatus.preparing;
    case 'ready_for_pickup':
      return OrderStatus.readyForPickup;
    case 'ready_for_delivery':
      return OrderStatus.readyForDelivery;
    case 'rejected':
      return OrderStatus.rejected;
    case 'completed':
      return OrderStatus.completed;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'pending_sync':
      return OrderStatus.pendingSync;
    default:
      return OrderStatus.unknown;
  }
}

class Order {
  final int? id;
  final String? uuid;
  final int? table;
  final int business;
  final List<OrderItem> orderItems;
  final List<Map<String, dynamic>>? tableUsers;
  final String? customerName;
  final String? customerPhone;
  final String? createdAt;
  final String? deliveredAt;
  final bool isPaid;
  final bool isSplitTable;
  final String? orderType;
  final dynamic takenByStaff;
  final dynamic payment;
  final dynamic creditDetails;
  final String? status;
  final String? statusDisplay;
  final String? approvedAt;
  final String? kitchenCompletedAt;
  final String? pickedUpByWaiterAt;
  final String? tempId;
  // YENİ: KDV ve Genel Toplam alanları eklendi
  final double? totalKdvAmount;
  final double? grandTotal;

  Order({
    this.id,
    this.uuid,
    this.table,
    required this.business,
    required this.orderItems,
    this.tableUsers,
    this.customerName,
    this.customerPhone,
    this.createdAt,
    this.deliveredAt,
    this.isPaid = false,
    this.isSplitTable = false,
    this.orderType,
    this.takenByStaff,
    this.payment,
    this.creditDetails,
    this.status,
    this.statusDisplay,
    this.approvedAt,
    this.kitchenCompletedAt,
    this.pickedUpByWaiterAt,
    this.tempId,
    this.totalKdvAmount, // YENİ
    this.grandTotal,     // YENİ
  });

  OrderStatus get orderStatusEnum => statusFromString(status);
  bool get isOffline => tempId != null && (id == -1 || id == null);
  dynamic get syncId => isOffline ? tempId : id;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      if (id != null && id != -1) 'id': id,
      'business': business,
      'order_items_data': orderItems.map((item) => item.toJson()).toList(),
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'table': table,
      'order_type': orderType ?? (table == null ? 'takeaway' : 'table'),
      'is_split_table': isSplitTable,
    };

    if (tableUsers != null && tableUsers!.isNotEmpty) {
      data['table_users_data'] = tableUsers!.map((userMap) => userMap['name'] as String).toList();
    } else {
      data['table_users_data'] = [];
    }

    return data;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int?,
      tempId: json['temp_id'] as String?,
      uuid: json['uuid'] as String?,
      table: json['table'] as int?,
      business: json['business'] as int? ?? 0,
      orderItems: (json['order_items'] as List<dynamic>?)
              ?.map((itemJson) =>
                  OrderItem.fromJson(itemJson as Map<String, dynamic>))
              .toList() ??
          [],
      tableUsers: (json['table_users'] as List<dynamic>?)
          ?.map((userJson) => userJson as Map<String, dynamic>)
          .toList(),
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      createdAt: json['created_at'] as String?,
      deliveredAt: json['delivered_at'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      isSplitTable: json['is_split_table'] as bool? ?? false,
      orderType: json['order_type'] as String?,
      takenByStaff: json['taken_by_staff'],
      payment: json['payment'],
      creditDetails: json['credit_details'],
      status: json['status'] as String?,
      statusDisplay: json['status_display'] as String?,
      approvedAt: json['approved_at'] as String?,
      kitchenCompletedAt: json['kitchen_completed_at'] as String?,
      pickedUpByWaiterAt: json['picked_up_by_waiter_at'] as String?,
      // YENİ: KDV ve Genel Toplam alanları JSON'dan okunuyor
      totalKdvAmount: double.tryParse(json['total_kdv_amount']?.toString() ?? '0.0'),
      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '0.0'),
    );
  }
}
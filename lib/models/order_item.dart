// lib/models/order_item.dart
import 'menu_item.dart';
import 'menu_item_variant.dart';
import 'order_item_extra.dart';

class OrderItem {
  final int? id;
  final MenuItem menuItem;
  final MenuItemVariant? variant;
  final double price; // Bu fiyat artık KDV hariç birim fiyattır.
  int quantity;
  List<OrderItemExtra>? extras;
  final String? tableUser;
  final String? kdsStatus;
  final DateTime? waiterPickedUpAt;
  // YENİ: KDV alanları eklendi
  final double? kdvRate;
  final double? kdvAmount;


  OrderItem({
    this.id,
    required this.menuItem,
    this.variant,
    required this.price,
    this.quantity = 1,
    this.extras,
    this.tableUser,
    this.kdsStatus,
    this.waiterPickedUpAt,
    this.kdvRate, // YENİ
    this.kdvAmount, // YENİ
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    List<OrderItemExtra>? extras;
    if (json['extras'] != null && json['extras'] is List) {
      extras = (json['extras'] as List)
          .map((extraJson) => OrderItemExtra.fromJson(extraJson))
          .toList();
    }

    MenuItem menuItem;
    if (json['menu_item'] is Map<String, dynamic>) {
        menuItem = MenuItem.fromJson(json['menu_item']);
    } else {
      // Fallback, normalde bu duruma düşmemeli
      menuItem = MenuItem(id: json['menu_item'] ?? 0, name: 'Bilinmiyor', image: '', description: '');
    }

    MenuItemVariant? variant;
    if (json['variant'] != null && json['variant'] is Map<String, dynamic>) {
        variant = MenuItemVariant.fromJson(json['variant']);
    }
    
    DateTime? parsedWaiterPickedUpAt;
    if (json['waiter_picked_up_at'] != null) {
      parsedWaiterPickedUpAt = DateTime.tryParse(json['waiter_picked_up_at']);
    }

    return OrderItem(
      id: json['id'] as int?,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      menuItem: menuItem,
      variant: variant,
      quantity: json['quantity'] ?? 1,
      extras: extras,
      tableUser: json['table_user'],
      kdsStatus: json['kds_status'] as String?,
      waiterPickedUpAt: parsedWaiterPickedUpAt,
      // YENİ: KDV alanları JSON'dan okunuyor
      kdvRate: double.tryParse(json['kdv_rate']?.toString() ?? '0.0') ?? 0.0,
      kdvAmount: double.tryParse(json['kdv_amount']?.toString() ?? '0.0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'menu_item_id': menuItem.id,
      'quantity': quantity,
    };

    if (variant != null) {
      data['variant_id'] = variant!.id;
    }

    if (extras != null && extras!.isNotEmpty) {
      data['extras'] = extras!.map((e) => e.toJson()).toList();
    }
    if (tableUser != null && tableUser!.isNotEmpty) {
      data['table_user'] = tableUser;
    }
    return data;
  }

  /// TakeawayOrderItemCard gibi eski `Map` yapısını bekleyen widget'lara
  /// veri aktarmak için kullanılır. Bu metot, nesnenin tüm detaylarını içerir.
  Map<String, dynamic> toJsonForCard() {
    return {
      'id': id,
      'quantity': quantity,
      'price': price,
      'delivered': waiterPickedUpAt != null,
      'is_awaiting_staff_approval': false,
      'menu_item': {
        'id': menuItem.id,
        'name': menuItem.name,
        'is_campaign_bundle': menuItem.isCampaignBundle,
        'image': menuItem.image,
        'category': menuItem.category
      },
      'variant': variant != null ? {
        'id': variant!.id,
        'name': variant!.name,
        'image': variant!.image,
      } : null,
      'extras': extras?.map((e) => e.toJsonForCard()).toList() ?? [],
      'kds_status': kdsStatus,
      'waiter_picked_up_at': waiterPickedUpAt?.toIso8601String(),
      // YENİ: KDV bilgileri eklendi
      'kdv_rate': kdvRate,
      'kdv_amount': kdvAmount,
    };
  }
}
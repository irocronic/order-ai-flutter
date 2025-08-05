// lib/models/notification_event_types.dart

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NotificationEventTypes {
  // Bu anahtarlar, Django'daki NOTIFICATION_EVENT_TYPES ile eşleşmelidir.
  static const String guestOrderPendingApproval = 'guest_order_pending_approval';
  static const String orderPendingApproval = 'order_pending_approval';
  static const String existingOrderNeedsReapproval = 'existing_order_needs_reapproval';
  static const String newApprovedOrder = 'new_approved_order';
  static const String orderApprovedForKitchen = 'order_approved_for_kitchen';
  static const String orderPreparingUpdate = 'order_preparing_update';
  static const String orderReadyForPickupUpdate = 'order_ready_for_pickup_update';
  static const String orderPickedUpByWaiter = 'order_picked_up_by_waiter';
  static const String orderOutForDeliveryUpdate = 'order_out_for_delivery_update';
  static const String orderItemDelivered = 'order_item_delivered';
  static const String orderFullyDelivered = 'order_fully_delivered';
  static const String orderCompletedUpdate = 'order_completed_update';
  static const String orderCancelledUpdate = 'order_cancelled_update';
  static const String orderRejectedUpdate = 'order_rejected_update';
  static const String orderUpdated = 'order_updated'; // Genel güncelleme
  static const String orderItemAdded = 'order_item_added';
  static const String orderItemRemoved = 'order_item_removed';
  static const String orderItemUpdated = 'order_item_updated';
  static const String orderTransferred = 'order_transferred';
  static const String waitingCustomerAdded = 'waiting_customer_added';
  static const String waitingCustomerUpdated = 'waiting_customer_updated';
  static const String waitingCustomerRemoved = 'waiting_customer_removed';
  static const String stockAdjusted = 'stock_adjusted';
  // *** YENİ EKLENEN ANAHTAR ***
  static const String pagerStatusUpdated = 'pager_status_updated';

  /// LOKALİZASYON DEĞİŞİKLİĞİ:
  /// Sabit (const) bir harita yerine, AppLocalizations (l10n) nesnesini alan
  /// ve dile çevrilmiş metinleri içeren bir harita döndüren bir metot kullanıyoruz.
  /// KULLANIM: NotificationEventTypes.getDisplayNames(l10n)[eventType]
  static Map<String, String> getDisplayNames(AppLocalizations l10n) {
    return {
      guestOrderPendingApproval: l10n.notificationEventGuestOrderPendingApproval,
      orderPendingApproval: l10n.notificationEventOrderPendingApproval,
      existingOrderNeedsReapproval: l10n.notificationEventExistingOrderNeedsReapproval,
      newApprovedOrder: l10n.notificationEventNewApprovedOrder,
      orderApprovedForKitchen: l10n.notificationEventOrderApprovedForKitchen,
      orderPreparingUpdate: l10n.notificationEventOrderPreparingUpdate,
      orderReadyForPickupUpdate: l10n.notificationEventOrderReadyForPickupUpdate,
      orderPickedUpByWaiter: l10n.notificationEventOrderPickedUpByWaiter,
      orderOutForDeliveryUpdate: l10n.notificationEventOrderOutForDeliveryUpdate,
      orderItemDelivered: l10n.notificationEventOrderItemDelivered,
      orderFullyDelivered: l10n.notificationEventOrderFullyDelivered,
      orderCompletedUpdate: l10n.notificationEventOrderCompletedUpdate,
      orderCancelledUpdate: l10n.notificationEventOrderCancelledUpdate,
      orderRejectedUpdate: l10n.notificationEventOrderRejectedUpdate,
      orderUpdated: l10n.notificationEventOrderUpdated,
      orderItemAdded: l10n.notificationEventOrderItemAdded,
      orderItemRemoved: l10n.notificationEventOrderItemRemoved,
      orderItemUpdated: l10n.notificationEventOrderItemUpdated,
      orderTransferred: l10n.notificationEventOrderTransferred,
      waitingCustomerAdded: l10n.notificationEventWaitingCustomerAdded,
      waitingCustomerUpdated: l10n.notificationEventWaitingCustomerUpdated,
      waitingCustomerRemoved: l10n.notificationEventWaitingCustomerRemoved,
      stockAdjusted: l10n.notificationEventStockAdjusted,
      // *** YENİ EKLENEN EŞLEŞTİRME ***
      pagerStatusUpdated: l10n.notificationEventPagerStatusUpdated,
    };
  }

  // Tüm event anahtarlarını bir liste olarak almak için.
  static const List<String> allEventKeys = [
    guestOrderPendingApproval,
    orderPendingApproval,
    existingOrderNeedsReapproval,
    newApprovedOrder,
    orderApprovedForKitchen,
    orderPreparingUpdate,
    orderReadyForPickupUpdate,
    orderPickedUpByWaiter,
    orderOutForDeliveryUpdate,
    orderItemDelivered,
    orderFullyDelivered,
    orderCompletedUpdate,
    orderCancelledUpdate,
    orderRejectedUpdate,
    orderUpdated,
    orderItemAdded,
    orderItemRemoved,
    orderItemUpdated,
    orderTransferred,
    waitingCustomerAdded,
    waitingCustomerUpdated,
    waitingCustomerRemoved,
    stockAdjusted,
    // *** YENİ EKLENEN ANAHTAR ***
    pagerStatusUpdated,
  ];
}
// lib/models/permission_preset.dart

import './staff_permission_keys.dart';
import './notification_event_types.dart';

/// Personel izinleri için bir preset modelini temsil eder.
class PermissionPreset {
  final String title;
  final List<String> screenPermissions;
  final List<String> notificationPermissions;

  const PermissionPreset({
    required this.title,
    required this.screenPermissions,
    required this.notificationPermissions,
  });
}

/// Hazır olarak tanımlanmış personel izin preset'lerini içerir.
class StaffPresets {
  static final PermissionPreset mutfakBar = PermissionPreset(
    title: "Mutfak-Bar",
    screenPermissions: [
      PermissionKeys.manageKds,
      // EKLENDİ: Mutfak personelinin kendi hesap ayarlarını görmesi için.
      PermissionKeys.viewAccountSettings,
    ],
    notificationPermissions: [
      // İSTENEN: Yeni sipariş mutfağa düşünce bildirim alır.
      NotificationEventTypes.orderApprovedForKitchen,
      // MEVCUT (Faydalı): Garson ürünü mutfaktan aldığında bildirim alır.
      NotificationEventTypes.orderPickedUpByWaiter,
      // MEVCUT (Faydalı): Sipariş iptal edildiğinde bildirim alır.
      NotificationEventTypes.orderCancelledUpdate,
      // MEVCUT (Faydalı): Mevcut siparişe yeni ürün eklendiğinde bildirim alır.
      NotificationEventTypes.orderItemAdded,
    ],
  );

  static final PermissionPreset garson = PermissionPreset(
    title: "Garson",
    screenPermissions: [
      PermissionKeys.takeOrders,
      PermissionKeys.viewPendingOrders,
      // EKLENDİ: Garsonun bekleme listesindeki müşterileri yönetmesi için.
      PermissionKeys.manageWaitingCustomers,
      PermissionKeys.manageCreditSales,
    ],
    notificationPermissions: [
      NotificationEventTypes.guestOrderPendingApproval,
      // MEVCUT (Faydalı): Personele ait onay bekleyen siparişler için bildirim.
      NotificationEventTypes.orderPendingApproval,
      NotificationEventTypes.existingOrderNeedsReapproval,
      NotificationEventTypes.orderReadyForPickupUpdate,
      NotificationEventTypes.orderTransferred,
      NotificationEventTypes.waitingCustomerAdded,
      NotificationEventTypes.waitingCustomerUpdated,
      NotificationEventTypes.waitingCustomerRemoved,
      NotificationEventTypes.orderPreparingUpdate,
    ],
  );

  static final PermissionPreset yonetici = PermissionPreset(
    title: "Yönetici",
    screenPermissions: [
      PermissionKeys.viewReports,
      PermissionKeys.manageStock,
      PermissionKeys.manageWaitingCustomers,
      PermissionKeys.managePagers,
      PermissionKeys.manageCampaigns,
    ],
    notificationPermissions: [
      NotificationEventTypes.orderCompletedUpdate,
      NotificationEventTypes.orderCancelledUpdate,
      NotificationEventTypes.waitingCustomerAdded,
      NotificationEventTypes.waitingCustomerRemoved,
      NotificationEventTypes.stockAdjusted,
    ],
  );

  /// Tüm preset'leri içeren liste.
  static final List<PermissionPreset> all = [
    mutfakBar,
    garson,
    yonetici,
  ];
}

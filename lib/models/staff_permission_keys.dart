// lib/models/staff_permission_keys.dart

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'notification_event_types.dart';

class PermissionKeys {
  static const String viewReports = 'view_reports';
  static const String manageCreditSales = 'manage_credit_sales';
  static const String manageMenu = 'manage_menu';
  static const String manageStock = 'manage_stock';
  static const String manageTables = 'manage_tables';
  static const String viewCompletedOrders = 'view_completed_orders';
  static const String viewPendingOrders = 'view_pending_orders';
  static const String takeOrders = 'take_orders';
  static const String manageStaff = 'manage_staff';
  static const String manageWaitingCustomers = 'manage_waiting_customers';
  static const String viewAccountSettings = 'view_account_settings';
  static const String manageKds = 'manage_kds';
  static const String managePagers = 'manage_pagers';
  static const String manageCampaigns = 'manage_campaigns';
  static const String manageKdsScreens = 'manage_kds_screens';

  static const List<String> allKeys = [
    viewReports,
    manageCreditSales,
    manageMenu,
    manageStock,
    manageTables,
    viewCompletedOrders,
    viewPendingOrders,
    takeOrders,
    manageStaff,
    manageWaitingCustomers,
    viewAccountSettings,
    manageKds,
    managePagers,
    manageCampaigns,
    manageKdsScreens,
  ];
  
  static const List<String> DEFAULT_STAFF_PERMISSIONS = [
    takeOrders,
    viewPendingOrders,
    viewCompletedOrders,
    manageWaitingCustomers,
    viewAccountSettings,
  ];

  static const List<String> DEFAULT_KITCHEN_PERMISSIONS = [
    manageKds,
    viewAccountSettings,
  ];

  // ==================== GÜNCELLEME BURADA BAŞLIYOR ====================
  // Django'daki core/models.py dosyasındaki varsayılanlarla eşleşir
  static const List<String> DEFAULT_STAFF_NOTIFICATION_PERMISSIONS = [
    // YENİ EKLENEN İZİNLER
    'guest_order_pending_approval',
    'order_pending_approval',
    'existing_order_needs_reapproval',
    'new_approved_order',
    // MEVCUT İZİNLER
    'order_ready_for_pickup_update',
    'order_picked_up_by_waiter',
    'order_out_for_delivery_update',
    'order_item_delivered',
    'waiting_customer_seated',
    'pager_status_updated',
  ];

  static const List<String> DEFAULT_KITCHEN_NOTIFICATION_PERMISSIONS = [
    'order_approved_for_kitchen',
    'order_item_added',
    'order_updated',
  ];
  // ==================== GÜNCELLEME BURADA BİTİYOR ====================
}

Map<String, String> getStaffPermissionDisplayNames(AppLocalizations l10n) {
  return {
    PermissionKeys.viewReports: l10n.permissionViewReports,
    PermissionKeys.manageCreditSales: l10n.permissionManageCreditSales,
    PermissionKeys.manageMenu: l10n.permissionManageMenu,
    PermissionKeys.manageStock: l10n.permissionManageStock,
    PermissionKeys.manageTables: l10n.permissionManageTables,
    PermissionKeys.viewCompletedOrders: l10n.permissionViewCompletedOrders,
    PermissionKeys.viewPendingOrders: l10n.permissionViewPendingOrders,
    PermissionKeys.takeOrders: l10n.permissionTakeOrders,
    PermissionKeys.manageStaff: l10n.permissionManageStaff,
    PermissionKeys.manageWaitingCustomers: l10n.permissionManageWaitingCustomers,
    PermissionKeys.viewAccountSettings: l10n.permissionViewAccountSettings,
    PermissionKeys.manageKds: l10n.permissionManageKds,
    PermissionKeys.manageKdsScreens: l10n.permissionManageKdsScreens,
    PermissionKeys.managePagers: l10n.permissionManagePagers,
    PermissionKeys.manageCampaigns: l10n.permissionManageCampaigns,
  };
}
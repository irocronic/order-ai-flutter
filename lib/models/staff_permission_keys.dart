// lib/models/staff_permission_keys.dart

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  // --- YENİ EKLENEN BÖLÜM: Varsayılan Rol İzinleri ---
  // Kurulum sihirbazında "Garson" rolü seçildiğinde atanacak izinler.
  static const List<String> DEFAULT_STAFF_PERMISSIONS = [
    takeOrders,
    viewPendingOrders,
    viewCompletedOrders,
    manageWaitingCustomers,
    viewAccountSettings,
  ];

  // Kurulum sihirbazında "Mutfak Personeli" rolü seçildiğinde atanacak izinler.
  static const List<String> DEFAULT_KITCHEN_PERMISSIONS = [
    manageKds,
    viewAccountSettings,
  ];
  // --- YENİ EKLENEN BÖLÜM SONU ---
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
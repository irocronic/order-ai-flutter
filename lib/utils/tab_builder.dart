// lib/utils/tab_builder.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../screens/create_order_screen.dart';
import '../screens/takeaway_order_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/manage_kds_screens_screen.dart';
import '../widgets/home/business_owner_home_content.dart';
import '../services/business_owner_home_state_manager.dart';
import '../models/staff_permission_keys.dart';
import '../services/user_session.dart';

class TabBuilder {
  static void buildAndSetActiveTabs({
    required BuildContext context,
    required String token,
    required int businessId,
    required VoidCallback onNavigateToKds,
    required Function(int) onTabChange,
    required bool hasStockAlerts,
    required Function(List<Widget>, List<BottomNavigationBarItem>) onTabsBuilt,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final stateManager = BusinessOwnerHomeStateManager.instance;
    
    final List<Widget> pages = [];
    final List<BottomNavigationBarItem> navBarItems = [];

    // Home tab
    pages.add(BusinessOwnerHomeContent(
      token: token,
      businessId: businessId,
      onTabChange: onTabChange,
      onNavigateToKds: onNavigateToKds,
      hasStockAlerts: hasStockAlerts,
    ));
    navBarItems.add(BottomNavigationBarItem(
      icon: const Icon(Icons.home_outlined),
      activeIcon: const Icon(Icons.home),
      label: l10n.homeTabLabel,
    ));

    // Table and Takeaway tabs
    if (stateManager.canAccessTab(PermissionKeys.takeOrders)) {
      pages.add(CreateOrderScreen(
        token: token,
        businessId: businessId,
        onGoHome: () => onTabChange(0),
      ));
      navBarItems.add(BottomNavigationBarItem(
        icon: ValueListenableBuilder<int>(
          valueListenable: stateManager.activeTableOrderCountNotifier,
          builder: (context, count, child) => stateManager.buildIconWithBadge(
            Icons.table_chart_outlined, 
            Icons.table_chart, 
            stateManager.activeTableOrderCountNotifier,
            1, // currentIndex için placeholder - gerçekte dışarıdan gelecek
            navBarItems,
            context,
          ),
        ),
        label: l10n.tableTabLabel,
      ));

      pages.add(TakeawayOrderScreen(
        token: token,
        businessId: businessId,
        onGoHome: () => onTabChange(0),
      ));
      navBarItems.add(BottomNavigationBarItem(
        icon: ValueListenableBuilder<int>(
          valueListenable: stateManager.activeTakeawayOrderCountNotifier,
          builder: (context, count, child) => stateManager.buildIconWithBadge(
            Icons.delivery_dining_outlined, 
            Icons.delivery_dining, 
            stateManager.activeTakeawayOrderCountNotifier,
            2, // currentIndex için placeholder
            navBarItems,
            context,
          ),
        ),
        label: l10n.takeawayTabLabel,
      ));
    }

    // KDS tabs
    _addKdsTabs(context, pages, navBarItems, token, businessId, l10n);

    // Notifications tab
    pages.add(NotificationScreen(
      token: token,
      businessId: businessId,
      onGoHome: () => onTabChange(0),
    ));
    navBarItems.add(BottomNavigationBarItem(
      icon: const Icon(Icons.notifications_outlined),
      activeIcon: const Icon(Icons.notifications),
      label: l10n.notificationsTabLabel,
    ));

    onTabsBuilt(pages, navBarItems);
  }

  static void _addKdsTabs(
    BuildContext context,
    List<Widget> pages,
    List<BottomNavigationBarItem> navBarItems,
    String token,
    int businessId,
    AppLocalizations l10n,
  ) {
    final stateManager = BusinessOwnerHomeStateManager.instance;
    
    bool showKdsTab = false;
    bool showKdsSetupTab = false;
    
    if (!stateManager.isLoadingKdsScreensNotifier.value) {
      bool hasGeneralKdsPermission = UserSession.userType == 'business_owner' ||
          UserSession.hasPagePermission(PermissionKeys.manageKds);

      if (hasGeneralKdsPermission) {
        if (stateManager.availableKdsScreensNotifier.value.isNotEmpty) {
          showKdsTab = true;
        } else if (UserSession.userType == 'business_owner') {
          showKdsSetupTab = true;
        }
      }
    }

    if (showKdsTab) {
      pages.add(Container(
        alignment: Alignment.center,
        child: Text(
          l10n.infoKdsSelectionPending,
          style: const TextStyle(color: Colors.white70),
        ),
      ));
      navBarItems.add(BottomNavigationBarItem(
        icon: ValueListenableBuilder<int>(
          valueListenable: stateManager.activeKdsOrderCountNotifier,
          builder: (context, count, child) => stateManager.buildIconWithBadge(
            Icons.kitchen_outlined,
            Icons.kitchen,
            stateManager.activeKdsOrderCountNotifier,
            navBarItems.length, // Dynamic index
            navBarItems,
            context,
          ),
        ),
        label: l10n.kitchenTabLabel,
      ));
    } else if (showKdsSetupTab) {
      pages.add(Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManageKdsScreensScreen(
                  token: token,
                  businessId: businessId,
                ),
              ),
            );
          },
          child: Text(l10n.buttonCreateKdsScreen),
        ),
      ));
      navBarItems.add(BottomNavigationBarItem(
        icon: const Icon(Icons.add_to_queue_outlined),
        activeIcon: const Icon(Icons.add_to_queue),
        label: l10n.kdsSetupTabLabel,
      ));
    }
  }
}
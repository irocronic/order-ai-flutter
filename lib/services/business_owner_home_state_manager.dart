// lib/services/business_owner_home_state_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

import '../models/kds_screen_model.dart';
import '../models/staff_permission_keys.dart';
import '../services/user_session.dart';
import '../services/order_service.dart';
import '../services/kds_service.dart';
import '../services/ingredient_service.dart';
import '../services/kds_management_service.dart';
import '../utils/notifiers.dart';

class BusinessOwnerHomeStateManager {
  // Singleton pattern
  static final BusinessOwnerHomeStateManager _instance = BusinessOwnerHomeStateManager._internal();
  static BusinessOwnerHomeStateManager get instance => _instance;
  BusinessOwnerHomeStateManager._internal();

  // State variables
  final ValueNotifier<int> activeTableOrderCountNotifier = ValueNotifier(0);
  final ValueNotifier<int> activeTakeawayOrderCountNotifier = ValueNotifier(0);
  final ValueNotifier<int> activeKdsOrderCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> hasStockAlertsNotifier = ValueNotifier(false);
  final ValueNotifier<List<KdsScreenModel>> availableKdsScreensNotifier = ValueNotifier([]);
  final ValueNotifier<bool> isLoadingKdsScreensNotifier = ValueNotifier(true);

  List<Widget> activeTabPages = [];
  List<BottomNavigationBarItem> activeNavBarItems = [];
  Timer? orderCountRefreshTimer;
  DateTime? lastRefreshTime;
  bool _isDisposed = false;

  void dispose() {
    if (_isDisposed) return;
    activeTableOrderCountNotifier.dispose();
    activeTakeawayOrderCountNotifier.dispose();
    activeKdsOrderCountNotifier.dispose();
    hasStockAlertsNotifier.dispose();
    availableKdsScreensNotifier.dispose();
    isLoadingKdsScreensNotifier.dispose();
    orderCountRefreshTimer?.cancel();
    _isDisposed = true;
  }

  Future<void> fetchActiveOrderCounts(String token, int businessId) async {
    if (_isDisposed) return;
    try {
      int kdsCount = 0;
      if (!_isDisposed && !isLoadingKdsScreensNotifier.value && availableKdsScreensNotifier.value.isNotEmpty) {
        kdsCount = await KdsService.fetchActiveKdsOrderCount(token, availableKdsScreensNotifier.value.first.slug);
      }

      final results = await Future.wait([
        OrderService.fetchActiveTableOrderCount(token, businessId),
        OrderService.fetchActiveTakeawayOrderCount(token, businessId),
        Future.value(kdsCount)
      ]);

      if (_isDisposed) return;
      activeTableOrderCountNotifier.value = results[0] as int;
      activeTakeawayOrderCountNotifier.value = results[1] as int;
      activeKdsOrderCountNotifier.value = results[2] as int;
      
      debugPrint("[StateManager] Order counts updated - Table: ${results[0]}, Takeaway: ${results[1]}, KDS: ${results[2]}");
    } catch (e) {
      debugPrint("❌ [StateManager] Aktif sipariş sayıları çekilirken hata: $e");
    }
  }

  Future<void> checkStockAlerts(String token) async {
    if (_isDisposed) return;
    if (!UserSession.hasPagePermission(PermissionKeys.manageStock)) {
      if (!_isDisposed) hasStockAlertsNotifier.value = false;
      return;
    }
    
    try {
      final ingredients = await IngredientService.fetchIngredients(token);
      bool alertFound = false;
      
      for (final ingredient in ingredients) {
        if (ingredient.trackStock && 
            ingredient.alertThreshold != null && 
            ingredient.stockQuantity <= ingredient.alertThreshold!) {
          alertFound = true;
          break;
        }
      }
      
      if (!_isDisposed) hasStockAlertsNotifier.value = alertFound;
    } catch (e) {
      debugPrint("Stok uyarıları kontrol edilirken hata: $e");
      if (!_isDisposed) hasStockAlertsNotifier.value = false;
    }
  }

  Future<void> fetchUserAccessibleKdsScreens(String token) async {
    if (_isDisposed) return;
    if (UserSession.businessId == null) {
      if (!_isDisposed) isLoadingKdsScreensNotifier.value = false;
      return;
    }
    
    if (UserSession.userType == 'customer' || UserSession.userType == 'admin') {
      if (!_isDisposed) {
        availableKdsScreensNotifier.value = [];
        isLoadingKdsScreensNotifier.value = false;
      }
      return;
    }
    
    if (!_isDisposed) isLoadingKdsScreensNotifier.value = true;
    List<KdsScreenModel> kdsToDisplay = [];
    
    try {
      if (_isDisposed) return;
      if (UserSession.userType == 'business_owner') {
        final allKdsScreensForBusiness = await KdsManagementService.fetchKdsScreens(token, UserSession.businessId!);
        kdsToDisplay = allKdsScreensForBusiness.where((kds) => kds.isActive).toList();
      } else if (UserSession.userType == 'staff' || UserSession.userType == 'kitchen_staff') {
        kdsToDisplay = UserSession.userAccessibleKdsScreens.where((kds) => kds.isActive).toList();
      }
      
      if (!_isDisposed) {
        availableKdsScreensNotifier.value = kdsToDisplay;
        debugPrint("StateManager: Kullanıcı için gösterilecek KDS ekranları (${kdsToDisplay.length} adet) belirlendi.");
      }
    } catch (e) {
      debugPrint("StateManager: Kullanıcının erişebileceği KDS ekranları işlenirken hata: $e");
      if (!_isDisposed) availableKdsScreensNotifier.value = [];
    } finally {
      if (!_isDisposed) isLoadingKdsScreensNotifier.value = false;
    }
  }

  bool canAccessTab(String permissionKey) {
    if (_isDisposed) return false;
    if (UserSession.userType == 'business_owner') return true;
    if (permissionKey == PermissionKeys.manageKds ||
        permissionKey == PermissionKeys.managePagers ||
        permissionKey == PermissionKeys.manageCampaigns ||
        permissionKey == PermissionKeys.manageKdsScreens) {
      return UserSession.userType == 'business_owner' ||
          UserSession.hasPagePermission(permissionKey);
    }
    return UserSession.hasPagePermission(permissionKey);
  }

  void buildActiveTabs(BuildContext context, String token, int businessId, VoidCallback onNavigateToKds, Function(int) onTabChange) {
    if (_isDisposed) return;
    final l10n = AppLocalizations.of(context)!;
    final List<Widget> pages = [];
    final List<BottomNavigationBarItem> navBarItems = [];

    // Import gerekli widget'lar burada olacak
    // Bu kısım BusinessOwnerHome'dan taşınacak çünkü widget import'ları gerekiyor

    activeTabPages = pages;
    activeNavBarItems = navBarItems;
  }

  Widget buildIconWithBadge(IconData defaultIcon, IconData activeIcon, ValueNotifier<int> countNotifier, int currentIndex, List<BottomNavigationBarItem> navBarItems, BuildContext context) {
    if (_isDisposed) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: countNotifier,
      builder: (context, count, child) {
        final l10n = AppLocalizations.of(context)!;
        bool isSelected = (currentIndex == 1 && defaultIcon == Icons.table_chart_outlined) ||
                          (currentIndex == 2 && defaultIcon == Icons.delivery_dining_outlined) ||
                          (navBarItems.length > 3 && currentIndex == 3 && navBarItems[3].label == l10n.kitchenTabLabel && defaultIcon == Icons.kitchen_outlined);

        return Badge(
          label: Text(count > 99 ? '99+' : count.toString()),
          isLabelVisible: count > 0,
          backgroundColor: Colors.redAccent,
          child: Icon(isSelected ? activeIcon : defaultIcon),
        );
      },
    );
  }

  void startOrderCountRefreshTimer(VoidCallback refreshCallback) {
    if (_isDisposed) return;
    orderCountRefreshTimer?.cancel();
    orderCountRefreshTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (_isDisposed) return;
      refreshCallback();
    });
  }

  void stopOrderCountRefreshTimer() {
    orderCountRefreshTimer?.cancel();
  }
}
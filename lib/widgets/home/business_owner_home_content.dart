// lib/widgets/home/business_owner_home_content.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Yeni modelleri import et
import '../../models/home_menu_item.dart';
import '../../models/home_menu_section.dart';

// Diğer importlar aynı kalıyor
import '../../services/user_session.dart';
import '../../screens/reports_screen.dart';
import '../../screens/staff_performance_screen.dart';
import '../../screens/credit_sales_screen.dart';
import '../../screens/manage_staff_screen.dart';
import '../../screens/manage_menu_screen.dart';
import '../../screens/manage_variant_list_screen.dart';
import '../../screens/stock_screen.dart';
import '../../screens/manage_table_screen.dart';
import '../../screens/category_list_screen.dart';
import '../../screens/completed_orders_screen.dart';
import '../../widgets/waiting_customers_modal.dart';
import '../../screens/account_settings_screen.dart';
import '../../models/staff_permission_keys.dart';
import '../../utils/notifiers.dart';
import '../../screens/pager_management_screen.dart';
import '../../screens/manage_campaigns_screen.dart';
import '../../screens/manage_kds_screens_screen.dart';
import '../../screens/schedule_management_screen.dart';
import '../../screens/printer_settings_screen.dart';
import '../../screens/business_settings_screen.dart';
import 'subscription_status_card.dart';

// GÜNCELLENDİ: Widget StatefulWidget'a dönüştürüldü
class BusinessOwnerHomeContent extends StatefulWidget {
  final String token;
  final int businessId;
  final Function(int) onTabChange;
  final VoidCallback onNavigateToKds;
  final bool hasStockAlerts;

  const BusinessOwnerHomeContent({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onTabChange,
    required this.onNavigateToKds,
    required this.hasStockAlerts,
  }) : super(key: key);

  @override
  State<BusinessOwnerHomeContent> createState() => _BusinessOwnerHomeContentState();
}

class _BusinessOwnerHomeContentState extends State<BusinessOwnerHomeContent> {
  // YENİ: Arama çubuğu için state değişkenleri
  final TextEditingController _searchController = TextEditingController();
  List<HomeMenuSection> _allSections = [];
  List<HomeMenuSection> _filteredSections = [];

  @override
  void initState() {
    super.initState();
    // Arama denetleyicisine bir dinleyici ekleyerek her değişiklikte filtreleme yap
    _searchController.addListener(_filterMenuItems);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // l10n nesnesi burada (veya build metodunda) başlatılmalı
    final l10n = AppLocalizations.of(context)!;
    // Menü seçeneklerini sadece bir kez yükle ve hem tam listeyi hem de filtrelenmiş listeyi başlat
    if (_allSections.isEmpty) {
      _allSections = _getMenuOptions(context, l10n);
      _filteredSections = _getAccessibleSections(_allSections);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMenuItems);
    _searchController.dispose();
    super.dispose();
  }

  // YENİ: Arama ve filtreleme mantığı
  void _filterMenuItems() {
    final query = _searchController.text.toLowerCase();
    final accessibleSections = _getAccessibleSections(_allSections);

    if (query.isEmpty) {
      setState(() {
        _filteredSections = accessibleSections;
      });
      return;
    }

    final List<HomeMenuSection> newFilteredList = [];
    for (var section in accessibleSections) {
      final filteredItems = section.items.where((item) {
        return item.title.toLowerCase().contains(query);
      }).toList();

      if (filteredItems.isNotEmpty) {
        newFilteredList.add(HomeMenuSection(title: section.title, items: filteredItems));
      }
    }

    setState(() {
      _filteredSections = newFilteredList;
    });
  }

  bool _canAccess(String permissionKey, bool requiresBusinessOwner) {
    if (requiresBusinessOwner) {
      return UserSession.userType == 'business_owner';
    }
    if (permissionKey.isEmpty) {
      return true;
    }
    return UserSession.hasPagePermission(permissionKey);
  }

  List<HomeMenuSection> _getAccessibleSections(List<HomeMenuSection> allSections) {
      return allSections.map((section) {
      final accessibleItems = section.items.where((item) {
        return _canAccess(item.permissionKey, item.requiresBusinessOwner);
      }).toList();

      if (accessibleItems.isEmpty) {
        return null;
      }
      return HomeMenuSection(title: section.title, items: accessibleItems);
    }).whereType<HomeMenuSection>().toList();
  }

  Widget _buildAlertIcon() {
    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, HomeMenuItem itemData) {
    final bool showStockAlert =
        itemData.permissionKey == PermissionKeys.manageStock && widget.hasStockAlerts;

    return Card(
      elevation: 5,
      margin: const EdgeInsets.all(6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: itemData.onTapBuilder(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    itemData.baseColor.withOpacity(0.75),
                    itemData.baseColor.withOpacity(0.95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(itemData.icon, size: 40, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      itemData.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14.5,
                        shadows: [
                          Shadow(
                            blurRadius: 1.0,
                            color: Colors.black26,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showStockAlert) _buildAlertIcon(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double childAspectRatio = 1.1;

    if (screenWidth > 1200) {
      crossAxisCount = 5;
      childAspectRatio = 1.0;
    } else if (screenWidth > 900) {
      crossAxisCount = 4;
      childAspectRatio = 1.05;
    } else if (screenWidth > 600) {
      crossAxisCount = 3;
      childAspectRatio = 1.0;
    } else if (screenWidth > 400) {
      crossAxisCount = 2;
      childAspectRatio = 1.1;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    }

    return Column(
      children: [
        const SubscriptionStatusCard(),
        // YENİ: Arama çubuğu eklendi
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.searchPlaceholder,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
            ),
          ),
        ),
        Expanded(
          child: _filteredSections.isEmpty && _searchController.text.isNotEmpty
              ? Center(child: Text(l10n.searchNoResults, style: const TextStyle(color: Colors.white70, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: _filteredSections.length,
                  itemBuilder: (context, index) {
                    final section = _filteredSections[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 8.0, top: 16.0, bottom: 4.0),
                          child: Text(
                            section.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 4.0,
                            mainAxisSpacing: 4.0,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: section.items.length,
                          itemBuilder: (context, itemIndex) {
                            return _buildGridItem(context, section.items[itemIndex]);
                          },
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // GÜNCELLENDİ: Bu metot artık widget değişkenlerine 'widget.' üzerinden erişiyor
  List<HomeMenuSection> _getMenuOptions(BuildContext context, AppLocalizations l10n) {
    return [
      HomeMenuSection(
        title: l10n.homeSectionOrderKitchen,
        items: [
          HomeMenuItem(icon: Icons.deck_outlined, title: l10n.homeMenuActiveTableOrders, baseColor: Colors.red.shade400, permissionKey: PermissionKeys.takeOrders, onTapBuilder: (ctx) => () => widget.onTabChange(1)),
          HomeMenuItem(icon: Icons.delivery_dining_outlined, title: l10n.homeMenuActiveTakeawayOrders, baseColor: Colors.deepOrange.shade400, permissionKey: PermissionKeys.takeOrders, onTapBuilder: (ctx) => () => widget.onTabChange(2)),
          HomeMenuItem(icon: Icons.kitchen_outlined, title: l10n.homeMenuKds, baseColor: Colors.deepOrange.shade600, permissionKey: PermissionKeys.manageKds, onTapBuilder: (ctx) => widget.onNavigateToKds),
          HomeMenuItem(icon: Icons.receipt_outlined, title: l10n.homeMenuPaidOrders, baseColor: Colors.lightGreen.shade600, permissionKey: PermissionKeys.viewCompletedOrders, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CompletedOrdersScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.groups_outlined, title: l10n.homeMenuWaitingCustomers, baseColor: Colors.lime.shade700, permissionKey: PermissionKeys.manageWaitingCustomers, onTapBuilder: (ctx) => () {
            showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => WaitingCustomersModal(token: widget.token, onCustomerListUpdated: () {
              shouldRefreshWaitingCountNotifier.value = true;
            }));
          }),
        ],
      ),
      HomeMenuSection(
        title: l10n.homeSectionMenuStock,
        items: [
          HomeMenuItem(icon: Icons.category_outlined, title: l10n.homeMenuCategoryManagement, permissionKey: PermissionKeys.manageMenu, baseColor: Colors.pink.shade400, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CategoryListScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.fastfood_outlined, title: l10n.homeMenuMenuItems, permissionKey: PermissionKeys.manageMenu, baseColor: Colors.indigo.shade400, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ManageMenuScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.view_list_outlined, title: l10n.homeMenuProductVariants, permissionKey: PermissionKeys.manageMenu, baseColor: Colors.indigo.shade600, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ManageVariantListScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.inventory_2_outlined, title: l10n.homeMenuStockManagement, permissionKey: PermissionKeys.manageStock, baseColor: Colors.brown.shade400, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => StockScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.campaign_outlined, title: l10n.homeMenuCampaignManagement, baseColor: Colors.amber.shade700, permissionKey: PermissionKeys.manageCampaigns, requiresBusinessOwner: true, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ManageCampaignsScreen(token: widget.token, businessId: widget.businessId)))),
        ],
      ),
      HomeMenuSection(
        title: l10n.homeSectionBusinessManagement,
        items: [
          HomeMenuItem(icon: Icons.table_chart_outlined, title: l10n.homeMenuTableManagement, baseColor: Colors.green.shade600, permissionKey: PermissionKeys.manageTables, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ManageTableScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.people_alt_outlined, title: l10n.homeMenuStaffManagement, baseColor: Colors.cyan.shade600, permissionKey: PermissionKeys.manageStaff, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ManageStaffScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.calendar_month_outlined, title: l10n.homeMenuStaffSchedule, baseColor: Colors.deepPurple.shade400, permissionKey: PermissionKeys.manageStaff, requiresBusinessOwner: true, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ScheduleManagementScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.credit_card_outlined, title: l10n.homeMenuCreditSales, baseColor: Colors.orange.shade700, permissionKey: PermissionKeys.manageCreditSales, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CreditSalesScreen(token: widget.token, businessId: widget.businessId)))),
        ],
      ),
      HomeMenuSection(
        title: l10n.homeSectionReports,
        items: [
          HomeMenuItem(icon: Icons.receipt_long_outlined, title: l10n.homeMenuGeneralReport, baseColor: Colors.teal.shade400, permissionKey: PermissionKeys.viewReports, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ReportsScreen(token: widget.token)))),
          HomeMenuItem(icon: Icons.leaderboard_outlined, title: l10n.homeMenuStaffPerformance, baseColor: Colors.purpleAccent.shade400, permissionKey: PermissionKeys.viewReports, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => StaffPerformanceScreen(token: widget.token, businessId: widget.businessId)))),
        ],
      ),
      HomeMenuSection(
        title: l10n.homeSectionSettings,
        items: [
          HomeMenuItem(icon: Icons.store_mall_directory_outlined, title: l10n.homeMenuBusinessSettings, baseColor: Colors.brown.shade500, permissionKey: PermissionKeys.manageStaff, requiresBusinessOwner: true, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => BusinessSettingsScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.settings_applications_outlined, title: l10n.homeMenuKdsSettings, baseColor: Colors.blueGrey.shade700, permissionKey: PermissionKeys.manageKdsScreens, requiresBusinessOwner: true, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => ManageKdsScreensScreen(token: widget.token, businessId: widget.businessId)))),
          HomeMenuItem(icon: Icons.settings_remote_outlined, title: l10n.homeMenuPagerManagement, baseColor: Colors.blueGrey.shade500, permissionKey: PermissionKeys.managePagers, requiresBusinessOwner: true, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const PagerManagementScreen()))),
          HomeMenuItem(icon: Icons.print_outlined, title: l10n.homeMenuPrinterSettings, baseColor: Colors.blueGrey.shade400, permissionKey: PermissionKeys.manageTables, requiresBusinessOwner: true, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()))),
          HomeMenuItem(icon: Icons.account_circle_outlined, title: l10n.homeMenuAccountSettings, baseColor: Colors.grey.shade600, permissionKey: PermissionKeys.viewAccountSettings, onTapBuilder: (ctx) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => AccountSettingsScreen(token: widget.token)))),
        ],
      )
    ];
  }
}
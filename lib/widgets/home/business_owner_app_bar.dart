// lib/widgets/home/business_owner_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/user_session.dart';
import '../../services/socket_service.dart';
import '../../services/shift_manager.dart';
import '../home/user_profile_avatar.dart';
import 'connection_status_indicator.dart';

class BusinessOwnerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final SocketService socketService;
  final ShiftManager shiftManager;
  final VoidCallback onLogout;
  final VoidCallback onCheckConnection;
  final List<Widget> activeTabPages;
  final List<BottomNavigationBarItem> activeNavBarItems;
  final int currentIndex;
  final Function(int) onBackToHome;

  const BusinessOwnerAppBar({
    Key? key,
    required this.socketService,
    required this.shiftManager,
    required this.onLogout,
    required this.onCheckConnection,
    required this.activeTabPages,
    required this.activeNavBarItems,
    required this.currentIndex,
    required this.onBackToHome,
  }) : super(key: key);

  String _getAppBarTitle(AppLocalizations l10n) {
    switch (UserSession.userType) {
      case 'kitchen_staff':
        return l10n.homePageTitleKitchenStaff;
      case 'staff':
        return l10n.homePageTitleStaff;
      case 'business_owner':
      default:
        return l10n.homePageTitleBusinessOwner;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        _getAppBarTitle(l10n),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40.0),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: shiftManager.buildShiftTimerWidget(context),
        ),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF283593), Color(0xFF455A64)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: _shouldShowBackButton(l10n)
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: l10n.tooltipGoToHome,
              onPressed: () => onBackToHome(0),
            )
          : null,
      actions: [
        ConnectionStatusIndicator(
          socketService: socketService,
          onTap: onCheckConnection,
        ),
        UserProfileAvatar(onLogout: onLogout),
      ],
    );
  }

  bool _shouldShowBackButton(AppLocalizations l10n) {
    if (activeTabPages.isEmpty || activeNavBarItems.isEmpty) return false;
    if (currentIndex >= activeTabPages.length || currentIndex >= activeNavBarItems.length) return false;
    
    final isNotHomeContent = !activeTabPages[currentIndex].toString().contains('BusinessOwnerHomeContent');
    final isNotKitchenOrKdsSetup = activeNavBarItems[currentIndex].label != l10n.kitchenTabLabel && 
                                   activeNavBarItems[currentIndex].label != l10n.kdsSetupTabLabel;
    
    return isNotHomeContent && isNotKitchenOrKdsSetup;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 40.0);
}
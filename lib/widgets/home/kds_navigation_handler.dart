// lib/widgets/home/kds_navigation_handler.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../models/kds_screen_model.dart';
import '../../screens/kds_screen.dart';
import '../../services/socket_service.dart';
import '../../services/user_session.dart';

class KdsNavigationHandler {
  static void navigateToKdsScreen({
    required BuildContext context,
    required String token,
    required int businessId,
    required List<KdsScreenModel> availableKdsScreens,
    required bool isLoading,
    required SocketService socketService,
    required Function() onGoHome,
    required Function(String slug) onKdsRoomSelected,
  }) {
    if (!context.mounted) return;
    
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.infoKdsScreensLoading),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    if (availableKdsScreens.isEmpty) {
      if (UserSession.userType == 'business_owner') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.infoCreateKdsScreenFirst)),
        );
        // Navigate to manage KDS screens
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.infoNoActiveKdsAvailable)),
        );
      }
      return;
    }

    if (availableKdsScreens.length == 1) {
      final kds = availableKdsScreens.first;
      onKdsRoomSelected(kds.slug);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KdsScreen(
            token: token,
            businessId: businessId,
            kdsScreenSlug: kds.slug,
            kdsScreenName: kds.name,
            onGoHome: onGoHome,
            socketService: socketService,
          ),
        ),
      );
    } else {
      _showKdsSelectionDialog(
        context: context,
        availableKdsScreens: availableKdsScreens,
        l10n: l10n,
        token: token,
        businessId: businessId,
        socketService: socketService,
        onGoHome: onGoHome,
        onKdsRoomSelected: onKdsRoomSelected,
      );
    }
  }

  static void _showKdsSelectionDialog({
    required BuildContext context,
    required List<KdsScreenModel> availableKdsScreens,
    required AppLocalizations l10n,
    required String token,
    required int businessId,
    required SocketService socketService,
    required Function() onGoHome,
    required Function(String slug) onKdsRoomSelected,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade900.withOpacity(0.95),
                  Colors.blue.shade500.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.dialogSelectKdsScreenTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white30),
                SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.3,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableKdsScreens.length,
                    itemBuilder: (BuildContext ctx, int index) {
                      final kds = availableKdsScreens[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.desktop_windows_rounded,
                          color: Colors.white70,
                        ),
                        title: Text(
                          kds.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          onKdsRoomSelected(kds.slug);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KdsScreen(
                                token: token,
                                businessId: businessId,
                                kdsScreenSlug: kds.slug,
                                kdsScreenName: kds.name,
                                onGoHome: onGoHome,
                                socketService: socketService,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    child: Text(
                      l10n.dialogButtonCancel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
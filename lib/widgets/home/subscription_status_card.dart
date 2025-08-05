// lib/widgets/home/subscription_status_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/user_session.dart';
import '../../screens/subscription_screen.dart';

class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Bu widget sadece işletme sahibi için görünür olmalı.
    if (UserSession.userType != 'business_owner') {
      return const SizedBox.shrink();
    }
    
    // --- DEĞİŞİKLİK BURADA BAŞLIYOR ---
    // UserSession içindeki notifier'ı dinlemek için ValueListenableBuilder kullanıyoruz.
    return ValueListenableBuilder<String?>(
      valueListenable: UserSession.subscriptionStatusNotifier,
      builder: (context, status, child) {
        final l10n = AppLocalizations.of(context)!;
        final trialEndsAtStr = UserSession.trialEndsAt; // Bu bilgiyi doğrudan alabiliriz

        String message = '';
        Color backgroundColor = Colors.blue.shade700;
        Color textColor = Colors.white;
        IconData iconData = Icons.info_outline;
        bool showButton = false;

        // Geri kalan mantık aynı, sadece 'status' değişkenini builder'dan alıyoruz.
        if (status == 'trial' && trialEndsAtStr != null) {
            try {
                final endDate = DateTime.parse(trialEndsAtStr);
                final remaining = endDate.difference(DateTime.now());
                final remainingDays = remaining.inDays;

                if (remainingDays >= 1) {
                    message = l10n.subscriptionStatusTrial(remainingDays.toString());
                    backgroundColor = Colors.green.shade600;
                    iconData = Icons.timer_outlined;
                    showButton = true;
                } else if (remaining.inHours > 0) {
                    message = l10n.subscriptionStatusTrialLastDay;
                    backgroundColor = Colors.orange.shade700;
                    iconData = Icons.warning_amber_rounded;
                    showButton = true;
                } else {
                    message = l10n.subscriptionStatusTrialEnded;
                    backgroundColor = Colors.red.shade700;
                    iconData = Icons.error_outline;
                    showButton = true;
                }
            } catch (e) {
              // Hata durumunda bir şey gösterme
            }
        } else if (status == 'inactive' || status == 'cancelled') {
            message = l10n.subscriptionStatusInactive;
            backgroundColor = Colors.red.shade800;
            iconData = Icons.cancel_outlined;
            showButton = true;
        }

        if (message.isEmpty) {
            return const SizedBox.shrink();
        }

        return Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            color: backgroundColor.withOpacity(0.9),
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
                children: [
                Icon(iconData, color: textColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                    message,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                    ),
                    ),
                ),
                if (showButton) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                    onPressed: () {
                        Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                        );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: backgroundColor,
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(l10n.subscriptionStatusButtonSubscribe),
                    ),
                ]
                ],
            ),
            ),
        );
      },
    );
    // --- DEĞİŞİKLİK BURADA BİTİYOR ---
  }
}
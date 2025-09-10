// lib/widgets/setup_wizard/menu_items/dialogs/limit_reached_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../screens/subscription_screen.dart';

class LimitReachedDialog extends StatelessWidget {
  final String title;
  final String message;

  const LimitReachedDialog({
    Key? key,
    required this.title,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          child: Text(l10n.dialogButtonLater),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text(l10n.dialogButtonUpgradePlan),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const SubscriptionScreen())
            );
          },
        ),
      ],
    );
  }
}
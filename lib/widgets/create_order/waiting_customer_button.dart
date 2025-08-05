// lib/widgets/create_order/waiting_customer_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// AppBar'da bekleyen müşteri sayısını ve modal açma butonunu gösterir.
class WaitingCustomerButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const WaitingCustomerButton({
    Key? key,
    required this.count,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.people_outline, size: 18),
      label: Text(
        l10n.waitingCustomerButtonLabel(count.toString()),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A5298).withOpacity(0.9),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 4,
      ),
    );
  }
}
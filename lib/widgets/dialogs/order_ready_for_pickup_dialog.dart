// lib/widgets/dialogs/order_ready_for_pickup_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // kIsWeb için eklendi
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart'; // Sesli bildirim için
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class OrderReadyForPickupDialog extends StatefulWidget {
  final Map<String, dynamic> notificationData;
  final VoidCallback onAcknowledge;

  const OrderReadyForPickupDialog({
    Key? key,
    required this.notificationData,
    required this.onAcknowledge,
  }) : super(key: key);

  @override
  _OrderReadyForPickupDialogState createState() => _OrderReadyForPickupDialogState();
}

class _OrderReadyForPickupDialogState extends State<OrderReadyForPickupDialog> {

  @override
  void initState() {
    super.initState();
    // *** DÜZELTME BURADA ***
    if (!kIsWeb) {
      try {
        FlutterRingtonePlayer().playNotification(asAlarm: true);
      } catch (e) {
        debugPrint("OrderReadyForPickupDialog: Zil sesi çalınırken hata: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int? orderId = widget.notificationData['order_id'];
    final String? orderType = widget.notificationData['order_type'];
    final int? tableNumber = widget.notificationData['table_number'];
    final String? customerName = widget.notificationData['customer_name'];

    String mainMessage;

    if (orderType == 'table' && tableNumber != null) {
      mainMessage = l10n.readyForPickupMessageTable(tableNumber.toString());
    } else if (orderType == 'takeaway' && customerName != null && customerName.isNotEmpty) {
      mainMessage = l10n.readyForPickupMessageTakeawayCustomer(customerName);
    } else if (orderType == 'takeaway' && orderId != null) {
      mainMessage = l10n.readyForPickupMessageTakeawayId(orderId.toString());
    } else {
      mainMessage = widget.notificationData['message'] ?? l10n.readyForPickupMessageDefault;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade700.withOpacity(0.95),
              Colors.amber.shade600.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.room_service_outlined, color: Colors.white, size: 50),
            const SizedBox(height: 16),
            Text(
              l10n.readyForPickupTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              mainMessage,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (orderId != null)
              Text(
                l10n.newOrderNotificationOrderId(orderId.toString()), // reused key
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade800,
                shadowColor: Colors.black.withOpacity(0.25),
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onAcknowledge();
              },
              child: Text(
                l10n.okButtonText, // reused key
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// lib/widgets/dialogs/new_order_notification_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NewOrderNotificationDialog extends StatelessWidget {
  final dynamic notificationData;
  final VoidCallback onAcknowledge;

  const NewOrderNotificationDialog({
    Key? key,
    required this.notificationData,
    required this.onAcknowledge,
  }) : super(key: key);

  // +++ YENİ: Mesaj oluşturma mantığını bu yardımcı fonksiyona taşıdık +++
  // Bu, build metodunu temizler ve kodun okunabilirliğini artırır.
  _DialogContent _buildDialogContent(AppLocalizations l10n) {
    final String? orderType = notificationData['order_type'];
    final int? tableNumber = notificationData['table_number'];
    final String? customerName = notificationData['customer_name'];
    final String? itemName = notificationData['item_name'];
    final bool isUpdate = notificationData['update'] == true;

    if (isUpdate) {
      final title = l10n.newOrderNotificationTitleUpdate;
      String message;
      if (itemName != null && itemName.isNotEmpty) {
        if (orderType == 'table' && tableNumber != null) {
          message = l10n.newOrderNotificationUpdateTable(itemName, tableNumber.toString());
        } else if (orderType == 'takeaway') {
          message = customerName != null
              ? l10n.newOrderNotificationUpdateTakeawayWithCustomer(itemName, customerName)
              : l10n.newOrderNotificationUpdateTakeaway(itemName);
        } else {
          message = l10n.newOrderNotificationUpdateGeneric(itemName);
        }
      } else {
        message = notificationData['message'] ?? l10n.newOrderNotificationDefaultMessage;
      }
      return _DialogContent(title: title, message: message);
    } else { // Yeni sipariş
      final title = l10n.newOrderNotificationTitleNew;
      String message;
      if (itemName != null && itemName.isNotEmpty) {
        if (orderType == 'table' && tableNumber != null) {
          message = l10n.newOrderNotificationNewOrderTable(tableNumber.toString(), itemName);
        } else if (orderType == 'takeaway') {
          message = customerName != null
              ? l10n.newOrderNotificationNewOrderTakeawayWithCustomer(customerName, itemName)
              : l10n.newOrderNotificationNewOrderTakeaway(itemName);
        } else {
          message = l10n.newOrderNotificationNewOrderGeneric(itemName);
        }
      } else {
        message = notificationData['message'] ?? l10n.newOrderNotificationDefaultMessage;
      }
      return _DialogContent(title: title, message: message);
    }
  }
  // ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int? orderId = notificationData['order_id'];
    final String? orderType = notificationData['order_type'];
    final int? tableNumber = notificationData['table_number'];
    final String? customerName = notificationData['customer_name'];
    final String? itemName = notificationData['item_name'];
    final bool isUpdate = notificationData['update'] == true;

    // +++ GÜNCELLENDİ: Artık başlık ve mesajı yardımcı fonksiyondan alıyoruz +++
    final content = _buildDialogContent(l10n);
    final String dialogTitle = content.title;
    final String mainMessage = content.message;
    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade700.withOpacity(0.9),
              Colors.green.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 40),
            const SizedBox(height: 16),
            Text(
              dialogTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mainMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (orderId != null)
              Text(
                l10n.newOrderNotificationOrderId(orderId.toString()),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (orderType == 'table' && tableNumber != null && !(isUpdate && itemName != null))
              Text(
                l10n.newOrderNotificationTableNumber(tableNumber.toString()),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            if (orderType == 'takeaway' && customerName != null && !(isUpdate && itemName != null))
              Text(
                l10n.newOrderNotificationCustomerName(customerName),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                shadowColor: Colors.black.withOpacity(0.25),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onAcknowledge();
              },
              child: Text(
                l10n.okButtonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// +++ YENİ: Başlık ve mesajı bir arada tutan basit bir yardımcı sınıf +++
class _DialogContent {
  final String title;
  final String message;
  _DialogContent({required this.title, required this.message});
}
// lib/widgets/dialogs/new_order_notification_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../main.dart'; // navigatorKey için

class NewOrderNotificationDialog extends StatelessWidget {
  final Map<String, dynamic> notificationData;
  final VoidCallback onAcknowledge;

  const NewOrderNotificationDialog({
    Key? key,
    required this.notificationData,
    required this.onAcknowledge,
  }) : super(key: key);

  /// Bildirim verisinden yerelleştirilmiş başlık ve mesajı oluşturan yardımcı fonksiyon.
  /// Bu fonksiyon, backend'den gelen yapısal veriyi kullanarak doğru çeviriyi seçer.
  _DialogContent _buildDialogContent(AppLocalizations l10n) {
    // Backend'den gelen yapısal veriyi güvenli bir şekilde al
    final extraData = notificationData['extra_data'] as Map<String, dynamic>?;
    final messageKey = extraData?['message_key'] as String?;
    final messageArgs = extraData?['message_args'] as Map<String, dynamic>? ?? {};

    // Geriye dönük uyumluluk için eski usül mesajı hazırda tut
    final String fallbackMessage = notificationData['message'] as String? ?? l10n.newOrderNotificationDefaultMessage;

    String finalMessage;
    String finalTitle = l10n.newOrderNotificationTitle; // Varsayılan başlık

    // Gelen anahtar kelimeye (message_key) göre doğru çeviriyi seç ve oluştur
    switch (messageKey) {
      case 'orderStatusUpdate':
        final String orderId = messageArgs['orderId']?.toString() ?? '';
        
        // --- GÜNCELLEME BAŞLANGICI ---
        // Backend'den artık çevrilmiş metin ('statusDisplay') yerine, durum anahtarı ('statusKey') bekliyoruz.
        final String statusKey = messageArgs['statusKey'] as String? ?? '';
        
        // Gelen anahtar kelimeye göre yerelleştirilmiş durum metnini alan fonksiyonu çağırıyoruz.
        final String localizedStatusDisplay = _getLocalizedStatus(statusKey, l10n);
        // --- GÜNCELLEME SONU ---

        finalTitle = l10n.orderStatusUpdateTitle;
        // .arb dosyasındaki ilgili çeviriye parametreleri gönderiyoruz.
        // Örn: "Order #{orderId} status updated: {statusDisplay}"
        finalMessage = l10n.orderStatusUpdateMessage(orderId, localizedStatusDisplay);
        break;

      case 'orderItemAdded':
        final String orderId = messageArgs['orderId']?.toString() ?? '';
        final String itemName = messageArgs['itemName'] as String? ?? '';

        finalTitle = l10n.orderItemAddedTitle;
        // .arb dosyasındaki ilgili çeviriye parametreleri gönderiyoruz.
        finalMessage = l10n.orderItemAddedMessage(itemName, orderId);
        break;

      default:
        // Eğer backend'den yeni yapı (`extra_data`) gelmezse veya bilinmeyen bir `message_key` gelirse,
        // eski metni doğrudan göster (geriye uyumluluk).
        finalMessage = fallbackMessage;
        break;
    }

    return _DialogContent(title: finalTitle, message: finalMessage);
  }
  
  /// Backend'den gelen durum anahtarını (`statusKey`) yerelleştirilmiş metne çevirir.
  /// Örn: "statusApproved" -> "Approved (Sent to Kitchen)"
  String _getLocalizedStatus(String statusKey, AppLocalizations l10n) {
    switch (statusKey) {
      case 'statusApproved':
        return l10n.statusApproved;
      case 'statusPreparing':
        return l10n.statusPreparing;
      case 'statusReadyForPickup':
        return l10n.statusReadyForPickup;
      // Diğer tüm durumlar için buraya case ekleyebilirsiniz.
      default:
        return statusKey; // Eğer eşleşen bir anahtar yoksa, anahtarın kendisini göster (hata ayıklama için)
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Yardımcı fonksiyondan yerelleştirilmiş başlık ve mesajı al
    final content = _buildDialogContent(l10n);
    final String dialogTitle = content.title;
    final String mainMessage = content.message;

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
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade800,
                shadowColor: Colors.black.withOpacity(0.25),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                // Global key kullanarak navigator'a erişmek, dialog'un
                // her zaman doğru context üzerinden kapanmasını sağlar.
                if (navigatorKey.currentState?.canPop() ?? false) {
                  Navigator.of(navigatorKey.currentContext!).pop();
                }
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

// Başlık ve mesajı bir arada tutan basit bir yardımcı sınıf
class _DialogContent {
  final String title;
  final String message;
  _DialogContent({required this.title, required this.message});
}
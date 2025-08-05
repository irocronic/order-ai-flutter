// lib/widgets/admin/pending_approval_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PendingApprovalCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback onApprove;

  const PendingApprovalCard({
    Key? key,
    required this.user,
    required this.onApprove,
  }) : super(key: key);

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Bilinmiyor';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(date.toLocal());
    } catch (e) {
      return dateStr; // Parse edilemezse orijinali göster
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userTypeDisplay = user['user_type'] == 'business_owner'
        ? 'İşletme Sahibi'
        : user['user_type'] == 'customer'
            ? 'Müşteri'
            : user['user_type']?.toString().capitalize() ?? 'Bilinmiyor';

    return Card(
      color: Colors.white.withOpacity(0.88),
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    user['username'] ?? 'N/A',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(userTypeDisplay, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: user['user_type'] == 'business_owner' ? Colors.blueGrey.shade600 : Colors.teal.shade400,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  labelPadding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text("Email: ${user['email'] ?? '-'}", style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
            if (user['first_name'] != null || user['last_name'] != null)
              Text(
                "Ad Soyad: ${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim(),
                style: TextStyle(color: Colors.grey.shade800, fontSize: 13)
              ),
            Text("Kayıt Tarihi: ${_formatDate(user['date_joined'])}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text("Onayla ve Aktifleştir"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
                ),
                onPressed: onApprove,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// String capitalize extension (utils/string_extensions.dart gibi bir dosyada olabilir)
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
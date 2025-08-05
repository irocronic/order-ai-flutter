// lib/widgets/shared/sync_queue_details_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sync_queue_item.dart';
import '../../services/cache_service.dart';

class SyncQueueDetailsModal extends StatefulWidget {
  const SyncQueueDetailsModal({Key? key}) : super(key: key);

  @override
  _SyncQueueDetailsModalState createState() => _SyncQueueDetailsModalState();
}

class _SyncQueueDetailsModalState extends State<SyncQueueDetailsModal> {
  late List<SyncQueueItem> _pendingItems;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingItems();
  }

  void _loadPendingItems() {
    setState(() {
      _isLoading = true;
    });
    // Doğrudan CacheService'ten bekleyenleri al
    _pendingItems = CacheService.instance.getPendingSyncItems();
    setState(() {
      _isLoading = false;
    });
  }

  /// Her bir senkronizasyon işleminin payload'ını çözüp okunabilir bir metin oluşturur.
  Map<String, String> _getSyncItemDetails(SyncQueueItem item) {
    try {
      final payloadString = utf8.decode(base64Decode(item.payload));
      final payload = jsonDecode(payloadString) as Map<String, dynamic>;

      switch (item.type) {
        case 'create_order':
          final orderType = payload['order_type'] ?? 'Bilinmiyor';
          if (orderType == 'takeaway') {
            return {
              'title': 'Yeni Paket Sipariş',
              'subtitle': 'Müşteri: ${payload['customer_name'] ?? 'Misafir'}'
            };
          } else {
            return {
              'title': 'Yeni Masa Siparişi',
              'subtitle': 'Masa No: ${payload['table'] ?? 'Bilinmiyor'}'
            };
          }
        case 'add_order_item':
          return {
            'title': 'Siparişe Ürün Ekleme',
            'subtitle': 'Sipariş ID: ${payload['orderId']?.toString().substring(0, 5)}...'
          };
        case 'mark_as_paid':
          return {
            'title': 'Ödeme Kaydı',
            'subtitle': 'Sipariş ID: ${payload['orderId']?.toString().substring(0, 5)}...'
          };
        case 'delete_order_item':
          return {
            'title': 'Ürün Silme',
            'subtitle': 'Kalem ID: ${payload['order_item_id']}'
          };
        default:
          return {'title': item.type, 'subtitle': 'Detay yok'};
      }
    } catch (e) {
      debugPrint("Payload parse error for item ${item.id}: $e");
      return {'title': item.type, 'subtitle': 'Payload okunamadı.'};
    }
  }

  IconData _getIconForItemType(String type) {
    switch (type) {
      case 'create_order':
        return Icons.note_add_outlined;
      case 'add_order_item':
        return Icons.playlist_add_outlined;
      case 'mark_as_paid':
        return Icons.price_check_outlined;
      case 'delete_order_item':
        return Icons.remove_shopping_cart_outlined;
      default:
        return Icons.sync;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.blueGrey.shade800.withOpacity(0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.sync_problem_outlined, color: Colors.white),
          SizedBox(width: 10),
          Text('Bekleyen İşlemler', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _pendingItems.isEmpty
                ? const Center(child: Text("Senkronize edilecek işlem yok.", style: TextStyle(color: Colors.white70)))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _pendingItems.length,
                    itemBuilder: (context, index) {
                      final item = _pendingItems[index];
                      final details = _getSyncItemDetails(item);
                      return Card(
                        color: Colors.white.withOpacity(0.1),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(_getIconForItemType(item.type), color: Colors.white),
                          title: Text(details['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            "${details['subtitle']!}\nEklenme: ${DateFormat('HH:mm:ss').format(DateTime.parse(item.createdAt))}",
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                          ),
                          trailing: item.status == 'failed'
                              ? Icon(Icons.error_outline, color: Colors.orangeAccent.shade100, size: 20)
                              : Icon(Icons.hourglass_top_outlined, color: Colors.white54, size: 20),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Kapat", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
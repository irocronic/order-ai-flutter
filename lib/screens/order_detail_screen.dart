// lib/screens/order_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/order.dart' as AppOrder;
import '../models/order_item.dart'; // OrderItem modelini import et

class OrderDetailScreen extends StatelessWidget {
  final AppOrder.Order order;

  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  /// String olarak gelen tarihi güvenli bir şekilde DateTime nesnesine çevirir.
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr)?.toLocal(); // .toLocal() ile yerel saate çevir
  }

  /// İki DateTime nesnesi arasındaki süreyi formatlayarak string olarak döndürür.
  String _formatDuration(BuildContext context, DateTime? start, DateTime? end) {
    final l10n = AppLocalizations.of(context)!;
    if (start == null || end == null) return l10n.durationNotCalculated;
    final duration = end.difference(start);

    if (duration.inSeconds < 0) return l10n.durationNotCalculated;

    String result = "";
    if (duration.inHours > 0) {
      result += "${duration.inHours} ${l10n.timelineUnitHour} ";
    }
    if (duration.inMinutes.remainder(60) > 0) {
      result += "${duration.inMinutes.remainder(60)} ${l10n.timelineUnitMinute} ";
    }
    result += "${duration.inSeconds.remainder(60)} ${l10n.timelineUnitSecond}";

    return result.trim().isEmpty ? l10n.durationZeroSeconds : result.trim();
  }

  /// Sipariş kalemleri listesinden en erken veya en geç zaman damgasını bulur.
  DateTime? _getExtremeItemTimestamp(
      List<OrderItem> items, DateTime? Function(OrderItem item) dateSelector,
      {bool findEarliest = true}) {
    DateTime? extremeDate;
    for (var item in items) {
      final currentDate = dateSelector(item);
      if (currentDate != null) {
        if (extremeDate == null) {
          extremeDate = currentDate;
        } else if (findEarliest && currentDate.isBefore(extremeDate)) {
          extremeDate = currentDate;
        } else if (!findEarliest && currentDate.isAfter(extremeDate)) {
          extremeDate = currentDate;
        }
      }
    }
    return extremeDate;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Ana zaman damgalarını parse et
    final DateTime? createdAt = _parseDate(order.createdAt);
    final DateTime? approvedAt = _parseDate(order.approvedAt);
    final DateTime? kitchenCompletedAt = _parseDate(order.kitchenCompletedAt);
    final DateTime? deliveredAt = _parseDate(order.deliveredAt);

    final DateTime? firstItemPickedUpByWaiterAt = _getExtremeItemTimestamp(
      order.orderItems,
      (item) => item.waiterPickedUpAt,
      findEarliest: true,
    );

    // Süreleri hesapla
    final approvalDuration = _formatDuration(context, createdAt, approvedAt);
    final prepDuration = _formatDuration(context, approvedAt, kitchenCompletedAt);
    final waiterPickupDuration = _formatDuration(context, kitchenCompletedAt, firstItemPickedUpByWaiterAt);
    final deliveryDuration = _formatDuration(context, firstItemPickedUpByWaiterAt, deliveredAt);
    final totalDuration = _formatDuration(context, createdAt, deliveredAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderDetailTitle(order.id.toString()), style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueGrey.shade800.withOpacity(0.9),
              Colors.blueGrey.shade900.withOpacity(0.95),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildInfoCard(context),
            const SizedBox(height: 16),
            _buildTimelineCard(
              context,
              approvalDuration,
              prepDuration,
              waiterPickupDuration,
              deliveryDuration,
              totalDuration,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.orderDetailCardGeneralInfo, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _buildInfoRow(l10n.orderDetailLabelId, '#${order.id}'),
            _buildInfoRow(l10n.orderDetailLabelCustomer, order.customerName ?? l10n.guestCustomerName),
            _buildInfoRow(l10n.orderDetailLabelType, order.orderType == 'table' ? l10n.orderDetailTypeTable : l10n.orderDetailTypeTakeaway),
            if (order.table != null) _buildInfoRow(l10n.orderDetailLabelTableNumber, order.table.toString()),
            _buildInfoRow(l10n.orderDetailLabelDate, order.createdAt != null ? DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(order.createdAt!).toLocal()) : l10n.dataNotAvailable),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, String approval, String prep, String pickup, String delivery, String total) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.orderDetailCardTimeline, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _buildTimelineTile(Icons.thumb_up_alt_outlined, l10n.timelineApprovalDuration, approval, Colors.blue),
            _buildTimelineTile(Icons.soup_kitchen_outlined, l10n.timelineKitchenDuration, prep, Colors.orange),
            _buildTimelineTile(Icons.pan_tool_alt_outlined, l10n.timelineWaiterPickupDuration, pickup, Colors.purple),
            _buildTimelineTile(Icons.delivery_dining, l10n.timelineCustomerDeliveryDuration, delivery, Colors.teal),
            const Divider(),
            _buildTimelineTile(Icons.timer_outlined, l10n.timelineTotalDuration, total, Colors.red, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildTimelineTile(IconData icon, String title, String duration, Color color, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
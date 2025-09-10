// lib/widgets/kds/kds_order_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../services/kds_service.dart';
import '../../utils/localization_helper.dart';

class KdsOrderCard extends StatefulWidget {
    final dynamic orderData;
    final bool isLoadingAction;
    final String token;
    final VoidCallback onOrderUpdated;

    const KdsOrderCard({
        Key? key,
        required this.orderData,
        required this.isLoadingAction,
        required this.token,
        required this.onOrderUpdated,
    }) : super(key: key);

    @override
    _KdsOrderCardState createState() => _KdsOrderCardState();
}

class _KdsOrderCardState extends State<KdsOrderCard> {
    Timer? _timer;
    int _elapsedSeconds = 0;
    
    // YENİ: Her bir kartın kendi içindeki aksiyonlar için yüklenme durumu
    bool _isUpdatingItem = false;

    static const String KDS_ITEM_STATUS_PENDING = 'pending_kds';
    static const String KDS_ITEM_STATUS_PREPARING = 'preparing_kds';
    static const String KDS_ITEM_STATUS_READY = 'ready_kds';

    @override
    void initState() {
        super.initState();
        _startTimerIfNeeded();
    }

    @override
    void didUpdateWidget(covariant KdsOrderCard oldWidget) {
        super.didUpdateWidget(oldWidget);
        if (widget.orderData['id'] != oldWidget.orderData['id'] ||
            widget.orderData['kds_screen_specific_status_display'] != oldWidget.orderData['kds_screen_specific_status_display']) {
            _timer?.cancel();
            _startTimerIfNeeded();
        }
    }

    @override
    void dispose() {
        _timer?.cancel();
        super.dispose();
    }
    
    void _startTimerIfNeeded() {
        final statusData = widget.orderData['kds_screen_specific_status_display'];
        
        final bool isKitchenProcessOngoing = statusData is Map<String, dynamic> && 
                                             (statusData['status_key'] == 'sent_to_kitchen' || statusData['status_key'] == 'preparing');

        if (isKitchenProcessOngoing && widget.orderData['created_at'] != null) {
            try {
                DateTime createdAt = DateTime.parse(widget.orderData['created_at']);
                _timer?.cancel();
                _updateElapsedSeconds(createdAt);
                _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                    if (!mounted) {
                        timer.cancel();
                        return;
                    }
                    _updateElapsedSeconds(createdAt);
                    
                    final newStatusData = widget.orderData['kds_screen_specific_status_display'];
                    if (newStatusData is! Map<String, dynamic> || 
                        newStatusData['status_key'] == 'ready_for_pickup' || 
                        newStatusData['status_key'] == 'all_picked_up') {
                        timer.cancel();
                    }
                });
            } catch (e) {
                debugPrint("KdsOrderCard - Timer start error: $e");
                if (mounted) setState(() => _elapsedSeconds = 0);
            }
        } else {
            _timer?.cancel();
        }
    }

    void _updateElapsedSeconds(DateTime startTime) {
        if (!mounted) return;
        final now = DateTime.now();
        setState(() => _elapsedSeconds = now.difference(startTime).inSeconds);
    }
    
    String _formatDuration(int totalSeconds) {
        if (totalSeconds < 0) totalSeconds = 0;
        final duration = Duration(seconds: totalSeconds);
        String twoDigits(int n) => n.toString().padLeft(2, "0");
        final minutes = twoDigits(duration.inMinutes.remainder(60));
        final seconds = twoDigits(duration.inSeconds.remainder(60));
        if (duration.inHours > 0) {
            return "${twoDigits(duration.inHours)}:$minutes:$seconds";
        }
        return "$minutes:$seconds";
    }

    void _showErrorSnackbar(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
    }
    
    // YENİ: API isteklerini yönetmek için merkezi ve güvenli bir yardımcı metot
    Future<void> _handleApiAction(Future<void> Function() action) async {
      if (_isUpdatingItem || !mounted) return;

      setState(() {
        _isUpdatingItem = true;
      });

      try {
        await action();
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          _showErrorSnackbar(l10n.errorGeneral(e.toString()));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingItem = false;
          });
        }
      }
    }

    // GÜNCELLENDİ: Hazırlamaya başla aksiyonu artık merkezi metodu kullanıyor
    Future<void> _handleStartPreparingItem(int orderItemId) async {
        final l10n = AppLocalizations.of(context)!;
        await _handleApiAction(() async {
            final response = await KdsService.startPreparingItem(widget.token, orderItemId);
            if (!mounted) return;
            if (response.statusCode == 200) {
                widget.onOrderUpdated();
            } else {
                _showErrorSnackbar(l10n.kdsCouldNotMarkPreparing(response.statusCode.toString()));
            }
        });
    }

    // GÜNCELLENDİ: Hazır olarak işaretle aksiyonu artık merkezi metodu kullanıyor
    Future<void> _handleMarkItemReady(int orderItemId) async {
        final l10n = AppLocalizations.of(context)!;
        await _handleApiAction(() async {
            final response = await KdsService.markItemReady(widget.token, orderItemId);
            if (!mounted) return;
            if (response.statusCode == 200) {
                widget.onOrderUpdated();
            } else {
                _showErrorSnackbar(l10n.kdsCouldNotMarkReady(response.statusCode.toString()));
            }
        });
    }
    
    String _getLocalizedKdsStatus(AppLocalizations l10n, dynamic statusData) {
        if (statusData is! Map<String, dynamic>) {
            return getLocalizedOrderStatus(context, widget.orderData['status']);
        }

        final String kdsName = statusData['kds_name'] ?? 'KDS';
        final String statusKey = statusData['status_key'] ?? 'unknown';
        final int readyCount = statusData['ready_items'] ?? 0;
        final int preparingCount = statusData['preparing_items'] ?? 0;
        final int totalCount = statusData['total_items'] ?? 0;
        
        switch (statusKey) {
            case 'no_action_needed':
                return l10n.kdsStatusDisplayNoActionNeeded(kdsName);
            case 'sent_to_kitchen':
                 return l10n.kdsStatusDisplaySentToKitchen(kdsName);
            case 'preparing':
                final int preparingAndReadyCount = preparingCount + readyCount;
                return l10n.kdsStatusDisplayPreparing(kdsName, preparingAndReadyCount.toString(), totalCount.toString());
            case 'ready_for_pickup':
                 return l10n.kdsStatusDisplayReadyForPickup(kdsName);
            case 'all_picked_up':
                return l10n.kdsStatusDisplayAllPickedUp(kdsName);
            default:
                return l10n.kdsStatusDisplayDefault(kdsName);
        }
    }

    @override
    Widget build(BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        final String orderId = widget.orderData['id'].toString();
        final String orderTypeDisplay = widget.orderData['order_type'] == 'table' ? l10n.orderTypeTable : l10n.orderTypeTakeaway;
        final String? tableNumber = widget.orderData['table_number']?.toString();
        final String? customerName = widget.orderData['customer_name'];
        final List<dynamic> items = widget.orderData['order_items'] as List<dynamic>? ?? [];

        final statusData = widget.orderData['kds_screen_specific_status_display'];
        final String cardHeaderStatusDisplay = _getLocalizedKdsStatus(l10n, statusData);
        final String statusKey = (statusData is Map<String, dynamic> ? statusData['status_key'] : null) ?? 'unknown';

        Color cardColor = Colors.grey.shade800;
        IconData statusIcon = Icons.error_outline;

        switch (statusKey) {
            case 'sent_to_kitchen':
                cardColor = Colors.blue.shade700;
                statusIcon = Icons.arrow_forward_ios_rounded;
                break;
            case 'preparing':
                cardColor = Colors.orange.shade700;
                statusIcon = Icons.restaurant_menu_outlined;
                break;
            case 'ready_for_pickup':
                 cardColor = Colors.teal.shade400;
                 statusIcon = Icons.check_circle_outline_rounded;
                break;
            case 'no_action_needed':
            case 'all_picked_up':
                 cardColor = Colors.green.shade600;
                 statusIcon = Icons.check_circle;
                break;
            default:
                cardColor = Colors.blueGrey.shade700;
                statusIcon = Icons.hourglass_empty_outlined;
        }

        return Card(
            color: cardColor.withOpacity(0.9),
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cardColor, width: 2),
            ),
            child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(
                                    child: Text(
                                        '#$orderId - $orderTypeDisplay${tableNumber != null ? " $tableNumber" : (customerName != null && customerName.isNotEmpty ? " ($customerName)" : "")}',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                    ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    _formatDuration(_elapsedSeconds),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.8)),
                                ),
                            ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                            children: [
                                Icon(statusIcon, color: Colors.white.withOpacity(0.9), size: 16),
                                const SizedBox(width: 5),
                                Expanded(
                                    child: Text(
                                        cardHeaderStatusDisplay,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.9)),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                    ),
                                ),
                            ],
                        ),
                        const Divider(color: Colors.white38, height: 10, thickness: 0.7),
                        if (items.isEmpty)
                            Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Center(child: Text(l10n.kdsNoItemsForKds, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12))),
                            )
                        else
                           Flexible(
                                child: ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    itemBuilder: (context, index) {
                                        final item = items[index];
                                        return _buildKdsItemRow(item, l10n);
                                    },
                                ),
                            ),
                    ],
                ),
            ),
        );
    }

    // GÜNCELLENDİ: Butonlar artık _isUpdatingItem durumuna göre yüklenme göstergesi gösterecek
    Widget _buildKdsItemRow(Map<String, dynamic> item, AppLocalizations l10n) {
        final String itemKdsStatus = item['kds_status'] ?? KDS_ITEM_STATUS_PENDING;
        final bool isItemReady = itemKdsStatus == KDS_ITEM_STATUS_READY;
        final bool isItemPreparing = itemKdsStatus == KDS_ITEM_STATUS_PREPARING;
        final bool canStartPreparing = itemKdsStatus == KDS_ITEM_STATUS_PENDING;

        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                    Expanded(
                        child: Text(
                            "${item['quantity']}x ${item['menu_item_name'] ?? l10n.unknownProduct}${item['variant_name'] != null ? ' (${item['variant_name']})' : ''}",
                            style: TextStyle(
                                fontSize: 14,
                                color: isItemReady ? Colors.white.withOpacity(0.6) : Colors.white,
                                fontWeight: !isItemReady ? FontWeight.w600 : FontWeight.normal,
                                decoration: isItemReady ? TextDecoration.lineThrough : null,
                            ),
                        ),
                    ),
                    const SizedBox(width: 8),

                    // YENİ: Butonların yerine işlem sırasında gösterilecek anlık yükleme animasyonu
                    if (_isUpdatingItem)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                    else if (canStartPreparing)
                        IconButton(
                            icon: const Icon(Icons.play_circle_fill_outlined, color: Colors.white),
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: l10n.kdsTooltipStartPreparing,
                            onPressed: widget.isLoadingAction ? null : () => _handleStartPreparingItem(item['id']),
                        )
                    else if (isItemPreparing)
                        IconButton(
                            icon: Icon(Icons.check_circle_outline, color: Colors.lightGreenAccent.shade100),
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: l10n.kdsTooltipMarkAsReady,
                            onPressed: widget.isLoadingAction ? null : () => _handleMarkItemReady(item['id']),
                        )
                    else if (isItemReady)
                        Icon(Icons.check_circle, color: Colors.greenAccent.shade400, size: 22),
                ],
            ),
        );
    }
}
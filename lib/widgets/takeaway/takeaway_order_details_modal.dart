// lib/widgets/takeaway/takeaway_order_details_modal.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:makarna_app/services/order_service.dart';
import '../../models/order.dart' as AppOrder;
import 'takeaway_order_card.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// TakeawayOrderScreen'de bir sipariş kartına tıklandığında
/// aşağıdan yukarı açılan ve sipariş detaylarını gösteren modal.
class TakeawayOrderDetailsModal extends StatefulWidget {
  final AppOrder.Order order;
  final String token;
  final VoidCallback onOrderUpdated; 
  final VoidCallback onCancel;
  final VoidCallback onAssignPager;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const TakeawayOrderDetailsModal({
    Key? key,
    required this.order,
    required this.token,
    required this.onOrderUpdated,
    required this.onCancel,
    required this.onAssignPager,
    required this.onApprove,
    required this.onReject,
  }) : super(key: key);

  @override
  State<TakeawayOrderDetailsModal> createState() => _TakeawayOrderDetailsModalState();
}

class _TakeawayOrderDetailsModalState extends State<TakeawayOrderDetailsModal> {
  late AppOrder.Order _currentOrder;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  /// Sadece bu siparişin güncel verisini API'den çeker ve modal'ı yeniler.
  Future<void> _refreshDetails() async {
    if (!mounted || _currentOrder.id == null) return;
    setState(() => _isLoadingDetails = true);
    try {
      final updatedOrderData = await OrderService.fetchOrderDetails(
        token: widget.token,
        orderId: _currentOrder.id!,
      );
      if (mounted && updatedOrderData != null) {
        setState(() {
          _currentOrder = AppOrder.Order.fromJson(updatedOrderData);
        });
        // Arkadaki listeyi de yenilemesi için ana callback'i çağır.
        widget.onOrderUpdated();
      }
    } catch (e) {
      debugPrint("Modal içinden sipariş detayı çekilirken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.tableOrderDetailsModalUpdateError), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  Future<void> _approveOrder() async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;
    setState(() => _isLoadingDetails = true);
    try {
      await OrderService.approveGuestOrder(token: widget.token, orderId: _currentOrder.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.takeawayOrderApproved), backgroundColor: Colors.green),
        );
        await _refreshDetails();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.takeawayErrorApproving(e.toString())), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _rejectOrder() async {
    Navigator.pop(context);
    widget.onReject(); 
  }

  Future<void> _cancelOrder() async {
    Navigator.pop(context);
    widget.onCancel();
  }

  Future<void> _assignPager() async {
    Navigator.pop(context);
    widget.onAssignPager(); 
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueGrey.shade800,
            Colors.blueGrey.shade900,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10.0),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          Expanded(
            child: _isLoadingDetails
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : TakeawayOrderCardWidget(
                    order: _currentOrder,
                    token: widget.token,
                    onCancel: _cancelOrder,
                    onOrderUpdated: _refreshDetails,
                    onAssignPager: _assignPager,
                    onApprove: _approveOrder,
                    onReject: _rejectOrder,
                    onTap: () {
                      Navigator.of(context).pop('edit_order');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
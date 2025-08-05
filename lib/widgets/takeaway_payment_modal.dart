// lib/widgets/takeaway_payment_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/order_service.dart';
import 'credit_payment_modal.dart';

/// Takeaway siparişi için ödeme seçeneklerini gösteren modal.
class TakeawayPaymentModal extends StatefulWidget {
  final String token;
  final dynamic order; // API'den gelen sipariş objesi
  final double amount; // Ödenecek toplam tutar
  final VoidCallback onSuccess; // Ödeme başarılı olduğunda çağrılacak callback

  const TakeawayPaymentModal({
    Key? key,
    required this.token,
    required this.order,
    required this.amount,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _TakeawayPaymentModalState createState() => _TakeawayPaymentModalState();
}

class _TakeawayPaymentModalState extends State<TakeawayPaymentModal> {
  bool isSubmitting = false;
  String message = '';
  bool isErrorMessage = false; // Hata mesajı olup olmadığını belirtir

  // Nakit, Kredi Kartı, Yemek Kartı için ödeme işlemi
  Future<void> _submitPayment(String paymentType) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      isSubmitting = true;
      message = '';
    });

    try {
      final response = await OrderService.markOrderAsPaid(
        token: widget.token,
        orderId: widget.order['id'],
        paymentType: paymentType,
        amount: widget.amount,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          message = l10n.paymentProcessingSuccess;
          isErrorMessage = false;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop(); // Bu modalı kapat
          widget.onSuccess(); // Ana ekranı yenilemek için callback'i çağır
        }
      } else {
        setState(() {
          message = l10n.paymentModalErrorWithDetails(
              response.statusCode.toString(), utf8.decode(response.bodyBytes));
          isErrorMessage = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = l10n.errorGeneral(e.toString());
          isErrorMessage = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // Veresiye kaydını yöneten fonksiyon (CreditPaymentModal'ı açar)
  void _handleCreditSale() {
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalContext) => CreditPaymentModal(
          token: widget.token,
          orderId: widget.order['id'],
          initialCustomerName: widget.order['customer_name'] ?? '',
          initialCustomerPhone: widget.order['customer_phone'] ?? '',
          onSuccess: () {
            widget.onSuccess();
          },
          onDismissParentModal: () {
            if (mounted) {
              Navigator.of(context).pop(); // Bu TakeawayPaymentModal'ı kapat
            }
          },
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade900.withOpacity(0.9),
            Colors.blue.shade400.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.paymentProcessingSelectTypeLabel, // reused key
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.paymentModalTotalAmount(widget.amount.toStringAsFixed(2), l10n.currencySymbol), // reused key
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isSubmitting ? null : () => _submitPayment('credit_card'),
                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent,)) : Text(l10n.paymentTypeCreditCard), // reused key
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isSubmitting ? null : () => _submitPayment('cash'),
                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent,)) : Text(l10n.paymentTypeCash), // reused key
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isSubmitting ? null : () => _submitPayment('food_card'),
                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent,)) : Text(l10n.paymentTypeFoodCard), // reused key
              ),
            ],
          ),
          const SizedBox(height: 16),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: isSubmitting ? null : _handleCreditSale,
                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : Text(l10n.paymentTypeCredit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // reused key
              ),
          const SizedBox(height: 16),
          if (message.isNotEmpty)
            Text(
              message,
              style: TextStyle(color: isErrorMessage ? Colors.redAccent.shade100 : Colors.greenAccent.shade100, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
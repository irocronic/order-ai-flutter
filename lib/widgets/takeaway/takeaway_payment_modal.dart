// lib/widgets/takeaway/takeaway_payment_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/order_service.dart';
import '../credit_payment_modal.dart';
import '../../models/order.dart' as AppOrder;
import '../../utils/currency_formatter.dart';

/// Takeaway siparişi için ödeme seçeneklerini gösteren modal.
class TakeawayPaymentModal extends StatefulWidget {
  final String token;
  final AppOrder.Order order;
  final double amount;
  final VoidCallback onSuccess;

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
  bool? isSuccess;
  String _currentPaymentType = '';

  Future<void> _submitPayment(String paymentType, AppLocalizations l10n) async {
    if (!mounted) return;
    setState(() {
      isSubmitting = true;
      message = '';
      isSuccess = null;
      _currentPaymentType = paymentType;
    });

    try {
      final response = await OrderService.markOrderAsPaid(
        token: widget.token,
        order: widget.order,
        paymentType: paymentType,
        amount: widget.amount,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          message = l10n.paymentProcessingSuccess;
          isSuccess = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          message = l10n.paymentModalErrorWithDetails(
              response.statusCode.toString(), utf8.decode(response.bodyBytes));
          isSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = l10n.errorGeneral(e.toString());
          isSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // *** DEĞİŞİKLİK BURADA BAŞLIYOR ***
  Future<void> _handleCreditSale() async { // async yapıldı
    if (mounted) {
      // CreditPaymentModal'dan dönecek sonucu bekle
      final bool? creditSaleSuccess = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalContext) => CreditPaymentModal(
          token: widget.token,
          orderId: widget.order.id!,
          initialCustomerName: widget.order.customerName ?? '',
          initialCustomerPhone: widget.order.customerPhone ?? '',
          // Hata veren onSuccess ve onDismissParentModal parametreleri buradan kaldırıldı.
        ),
      );

      // Eğer veresiye satışı başarılı olduysa (true döndüyse),
      // bu modalı da kapat ve ana ekrana 'credit_success' gibi bir sinyal gönder.
      if (creditSaleSuccess == true && mounted) {
        Navigator.of(context).pop('credit_success');
      }
    }
  }
  // *** DEĞİŞİKLİK BURADA BİTİYOR ***

  String _getPaymentTypeDisplayName(String type, AppLocalizations l10n) {
    switch (type) {
      case 'credit_card':
        return l10n.paymentTypeCreditCard;
      case 'cash':
        return l10n.paymentTypeCash;
      case 'food_card':
        return l10n.paymentTypeFoodCard;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInsets),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.95),
              Colors.blue.shade500.withOpacity(0.9),
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
                  l10n.paymentProcessingSelectTypeLabel,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.newOrderBasketTotalLabel(CurrencyFormatter.format(widget.amount)),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8), foregroundColor: Colors.black, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: isSubmitting ? null : () => _submitPayment('credit_card', l10n),
                  child: isSubmitting && _currentPaymentType == 'credit_card' ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent,)) : Text(l10n.paymentTypeCreditCard),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8), foregroundColor: Colors.black, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: isSubmitting ? null : () => _submitPayment('cash', l10n),
                  child: isSubmitting && _currentPaymentType == 'cash' ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent,)) : Text(l10n.paymentTypeCash),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.8), foregroundColor: Colors.black, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: isSubmitting ? null : () => _submitPayment('food_card', l10n),
                  child: isSubmitting && _currentPaymentType == 'food_card' ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent,)) : Text(l10n.paymentTypeFoodCard),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              onPressed: isSubmitting ? null : _handleCreditSale,
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : Text(l10n.paymentTypeCredit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            if (message.isNotEmpty)
              Text(
                message,
                style: TextStyle(
                    color: isSuccess == true
                        ? Colors.greenAccent.shade100
                        : Colors.redAccent.shade100,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
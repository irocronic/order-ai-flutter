// lib/widgets/payment_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/order_service.dart';
import 'credit_payment_modal.dart';
import '../models/order.dart' as AppOrder;
import '../utils/currency_formatter.dart';
import '../screens/qr_payment_screen.dart'; // YENİ EKRAN İÇİN IMPORT

class PaymentModal extends StatefulWidget {
  final String token;
  final AppOrder.Order order;
  final double amount;
  final VoidCallback onSuccess;

  const PaymentModal({
    Key? key,
    required this.token,
    required this.order,
    required this.amount,
    required this.onSuccess,
  }) : super(key: key);

  @override
  _PaymentModalState createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  bool _isProcessing = false;
  String _currentPaymentType = '';

  Future<void> _submitPayment(String paymentType) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isProcessing = true;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.paymentProcessingSuccess), backgroundColor: Colors.green),
        );
        // Başarılı olduğunda modalı 'true' sonucuyla kapat.
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.paymentModalErrorWithDetails(response.statusCode.toString(), utf8.decode(response.bodyBytes))),
            backgroundColor: Colors.redAccent,
          ),
        );
        // Başarısız olursa modalı 'false' sonucuyla kapat.
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorGeneral(e.toString())), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  
  void _handleCreditSale() {
    if (mounted) {
      showModalBottomSheet<bool>( // Dönecek değeri belirtiyoruz
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (modalContext) => CreditPaymentModal(
          token: widget.token,
          orderId: widget.order.id!,
          initialCustomerName: widget.order.customerName ?? '',
          initialCustomerPhone: widget.order.customerPhone ?? '',
        ),
      ).then((wasSuccessful) {
        if (wasSuccessful == true) {
          // Veresiye işlemi başarılı olursa bu modalı da kapatıp ana ekrana haber ver.
          Navigator.of(context).pop(true);
        }
      });
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
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
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
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.8), 
                      foregroundColor: Colors.black, 
                      elevation: 4, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isProcessing ? null : () => _submitPayment('credit_card'),
                    child: _isProcessing && _currentPaymentType == 'credit_card' 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent)
                          ) 
                        : Text(
                            l10n.paymentTypeCreditCard,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.8), 
                      foregroundColor: Colors.black, 
                      elevation: 4, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isProcessing ? null : () => _submitPayment('cash'),
                    child: _isProcessing && _currentPaymentType == 'cash' 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent)
                          ) 
                        : Text(
                            l10n.paymentTypeCash,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.8), 
                      foregroundColor: Colors.black, 
                      elevation: 4, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isProcessing ? null : () => _submitPayment('food_card'),
                    child: _isProcessing && _currentPaymentType == 'food_card' 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent)
                          ) 
                        : Text(
                            l10n.paymentTypeFoodCard,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
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
              onPressed: _isProcessing ? null : _handleCreditSale,
              child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : Text(l10n.paymentTypeCredit, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            // YENİ EKLENEN QR İLE ÖDE BUTONU
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_2),
              label: Text(l10n.paymentTypeQrCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade400,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isProcessing
                  ? null
                  : () {
                      // Önce mevcut modalı kapat
                      Navigator.of(context).pop(); 
                      // Sonra QR ödeme ekranını aç
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => QrPaymentScreen(
                            order: widget.order,
                            token: widget.token,
                          ),
                        ),
                      ).then((paymentResult) {
                        // QR ekranından bir sonuçla dönülürse
                        if (paymentResult == true) {
                          // Ödeme başarılı, ana sipariş ekranına haber ver.
                          widget.onSuccess();
                        }
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }
}
// lib/widgets/credit_payment_modal.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/order_service.dart';

/// Veresiye ödeme detaylarını girmek için kullanılan modal.
class CreditPaymentModal extends StatefulWidget {
  final String token;
  final int orderId;
  final String initialCustomerName;
  final String initialCustomerPhone;
  // GÜNCELLEME: Bu callback'ler artık gerekli değil, çünkü modal bir sonuç döndürecek.
  // final VoidCallback onSuccess;
  // final VoidCallback onDismissParentModal;

  const CreditPaymentModal({
    Key? key,
    required this.token,
    required this.orderId,
    this.initialCustomerName = '',
    this.initialCustomerPhone = '',
    // GÜNCELLEME: Bu callback'ler constructor'dan da kaldırıldı.
    // required this.onSuccess,
    // required this.onDismissParentModal,
  }) : super(key: key);

  @override
  _CreditPaymentModalState createState() => _CreditPaymentModalState();
}

class _CreditPaymentModalState extends State<CreditPaymentModal> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool isSubmitting = false;
  String message = '';
  bool isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialCustomerName;
    _phoneController.text = widget.initialCustomerPhone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCreditDetails() async {
    final l10n = AppLocalizations.of(context)!;

    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      setState(() {
        message = l10n.creditPaymentValidationError;
        isSuccessMessage = false;
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      message = '';
    });

    try {
      final response = await OrderService.saveCreditPayment(
        token: widget.token,
        orderId: widget.orderId,
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          message = l10n.creditPaymentSuccess;
          isSuccessMessage = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          // *** DEĞİŞİKLİK BURADA ***
          // Artık sadece kendimizi kapatıp 'true' sonucu döndürüyoruz.
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          message = l10n.creditPaymentErrorWithDetails(response.statusCode.toString(), utf8.decode(response.bodyBytes));
          isSuccessMessage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = l10n.errorGeneral(e.toString());
          isSuccessMessage = false;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInsets),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, -4))],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.creditPaymentTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: l10n.creditPaymentCustomerNameLabel,
                  labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: l10n.creditPaymentPhoneLabel,
                  labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white70,
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: l10n.creditPaymentNotesLabel,
                  labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white70,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: isSubmitting ? null : _saveCreditDetails,
                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)) : Text(l10n.creditPaymentSaveButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              if (message.isNotEmpty)
                Text(
                  message,
                  style: TextStyle(color: isSuccessMessage ? Colors.green : Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
// lib/screens/payment_processing_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/api_service.dart';

class PaymentProcessingScreen extends StatefulWidget {
  final String token;
  final dynamic order;
  final double amount;

  const PaymentProcessingScreen({
    Key? key,
    required this.token,
    required this.order,
    required this.amount,
  }) : super(key: key);

  @override
  _PaymentProcessingScreenState createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  bool isSubmitting = false;
  String message = '';
  bool isSuccessMessage = false;

  Future<void> _submitPayment(String paymentType) async {
    final url = ApiService.getUrl('/payments/');
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() {
        isSubmitting = true;
        message = '';
      });
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          'order': widget.order['id'],
          'payment_type': paymentType,
          'amount': widget.amount,
        }),
      );
      if (mounted) {
        if (response.statusCode == 201) {
          setState(() {
            message = l10n.paymentProcessingSuccess;
            isSuccessMessage = true;
          });
        } else {
          setState(() {
            message = l10n.paymentProcessingError;
            isSuccessMessage = false;
          });
        }
      }
    } catch (e) {
      if(mounted) {
        setState(() {
          message = l10n.errorGeneral(e.toString());
          isSuccessMessage = false;
        });
      }
    } finally {
      if(mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.paymentProcessingScreenTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF283593),
                Color(0xFF455A64),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Card(
                color: Colors.white.withOpacity(0.85),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.paymentProcessingTableLabel(widget.order['table'].toString()),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.paymentProcessingAmountLabel(widget.amount.toStringAsFixed(2)),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.paymentProcessingSelectTypeLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      // Payment buttons
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () => _submitPayment('credit_card'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: isSubmitting
                            ? const CircularProgressIndicator()
                            : Text(l10n.paymentTypeCreditCard),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () => _submitPayment('cash'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: isSubmitting
                            ? const CircularProgressIndicator()
                            : Text(l10n.paymentTypeCash),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () => _submitPayment('food_card'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: isSubmitting
                            ? const CircularProgressIndicator()
                            : Text(l10n.paymentTypeFoodCard),
                      ),

                      const SizedBox(height: 20),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          style: TextStyle(color: isSuccessMessage ? Colors.green : Colors.red),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// lib/screens/qr_payment_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/order_service.dart';
import '../models/order.dart' as AppOrder;
import '../utils/currency_formatter.dart';

class QrPaymentScreen extends StatefulWidget {
  final AppOrder.Order order;
  final String token;

  const QrPaymentScreen({
    Key? key,
    required this.order,
    required this.token,
  }) : super(key: key);

  @override
  _QrPaymentScreenState createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> {
  String? _qrDataString;
  String? _transactionId;
  String _errorMessage = '';
  bool _isLoading = true;
  Timer? _pollingTimer;
  int _countdown = 120; // 2 dakika
  Timer? _countdownTimer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // initState'te localization kullanmayın
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _initiatePayment(); // Burada güvenli
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    try {
      final response = await OrderService.initiateQrPayment(
        token: widget.token,
        orderId: widget.order.id!,
      );
      if (mounted) {
        setState(() {
          _qrDataString = response['qr_data'];
          _transactionId = response['transaction_id'];
          _isLoading = false;
        });
        _startPolling();
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'QR ödeme başlatılırken hata: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkPaymentStatus();
    });
  }
  
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            timer.cancel();
            _pollingTimer?.cancel();
            _errorMessage = 'QR ödeme süresi doldu';
          }
        });
      }
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_transactionId == null) return;

    try {
      final response = await OrderService.checkQrPaymentStatus(
        token: widget.token,
        orderId: widget.order.id!,
        transactionId: _transactionId!,
      );

      final status = response['status'];
      if (status == 'paid') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) {
          // Başarılı ödeme animasyonu veya mesajı göster
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 16),
                  const Text('Ödeme başarıyla tamamlandı!', textAlign: TextAlign.center),
                ],
              ),
            ),
          );
          // 2 saniye sonra ekranı kapat ve başarı durumunu geri döndür
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
      } else if (status == 'failed' || status == 'expired') {
        _pollingTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) {
          setState(() {
            _errorMessage = 'QR ödeme başarısız veya süresi doldu';
          });
        }
      }
    } catch (e) {
      // Polling sırasında hata olursa loglayabiliriz ama kullanıcıya sürekli hata göstermeyelim.
      debugPrint("QR Status polling error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalAmount = widget.order.grandTotal ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('QR Kod ile Ödeme')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : _errorMessage.isNotEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 50),
                        const SizedBox(height: 16),
                        Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Geri'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('QR kodu bankanızın mobil uygulaması ile okutun', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.5), spreadRadius: 2, blurRadius: 7, offset: const Offset(0, 3))],
                          ),
                          child: QrImageView(
                            data: _qrDataString!,
                            version: QrVersions.auto,
                            size: 250.0,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Toplam Tutar:', style: Theme.of(context).textTheme.titleLarge),
                        Text(CurrencyFormatter.format(totalAmount), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Text("$_countdown saniye kaldı", style: TextStyle(color: _countdown < 20 ? Colors.red : Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
        ),
      ),
    );
  }
}
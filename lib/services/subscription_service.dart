// lib/services/subscription_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, debugPrint;
import 'api_service.dart';
import 'user_session.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../screens/business_owner_home.dart';

class SubscriptionService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Set<String> _productIds = {
    'aylik_abonelik_01',
    'yillik_abonelik_01',
    'silver_aylik_paket_01',
    'silver_yillik_paket_01',
    'gold_aylik_paket_01',
    'gold_yillik_paket_01',
  };

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  Completer<bool> _purchaseCompleter = Completer<bool>();

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint("Web platformunda uygulama içi satın alma desteklenmiyor.");
      return;
    }
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint("Satın alma servisleri kullanılamıyor.");
      return;
    }
    await _getProducts();
    _subscription = _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      debugPrint("Satın alma stream hatası: $error");
    });
  }

  Future<void> _getProducts() async {
    ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_productIds);
    if (response.error != null) {
      debugPrint("Ürünler getirilirken hata: ${response.error!.message}");
      _products = [];
      return;
    }
    _products = response.productDetails;
  }

  Future<bool> buySubscription(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    if (_purchaseCompleter.isCompleted) {
      _purchaseCompleter = Completer<bool>();
    }
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    return _purchaseCompleter.future;
  }

  /// Kullanıcının geçmiş satın alımlarını geri yükler.
  Future<void> restorePurchases() async {
    if (kIsWeb) return;
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint("Abonelikleri geri yüklerken hata oluştu: $e");
      throw Exception('Geri yükleme işlemi başarısız oldu.');
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Ödeme bekleniyor...
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint("Satın alma hatası: ${purchaseDetails.error}");
        if (!_purchaseCompleter.isCompleted) {
          _purchaseCompleter.complete(false);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _handleSuccessfulPurchase(purchaseDetails);
      }
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _refreshSessionAndNavigate() async {
    try {
      // UserSession zaten _verifyPurchaseOnBackend içinde güncellendiği için
      // burada tekrar refresh etmeye gerek yok. Direkt yönlendirme yapabiliriz.
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => BusinessOwnerHome(
                    token: UserSession.token,
                    businessId: UserSession.businessId!,
                  )),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint("Oturum yenileme ve yönlendirme sırasında hata: $e");
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    String provider = defaultTargetPlatform == TargetPlatform.iOS
        ? 'apple_app_store'
        : 'google_play';
    String verificationToken = purchaseDetails.verificationData.serverVerificationData;

    try {
      final success = await _verifyPurchaseOnBackend(
          provider, verificationToken, purchaseDetails.productID);
      if (success) {
        debugPrint("Backend doğrulaması başarılı. Oturum yenileniyor ve yönlendirme yapılıyor...");
        await _refreshSessionAndNavigate();
        if (!_purchaseCompleter.isCompleted) {
          _purchaseCompleter.complete(true);
        }
      } else {
        if (!_purchaseCompleter.isCompleted) {
          _purchaseCompleter.completeError(Exception("Backend doğrulaması başarısız oldu."));
        }
      }
    } catch (e) {
      if (!_purchaseCompleter.isCompleted) {
        _purchaseCompleter.completeError(e);
      }
    }
  }

  Future<bool> _verifyPurchaseOnBackend(String provider, String token, String productId) async {
    final url = ApiService.getUrl('/subscriptions/verify-purchase/');
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${UserSession.token}",
        },
        body: jsonEncode({
          'provider': provider,
          'token': token,
          'product_id': productId,
        }),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        
        // +++++++++++++++++++ DEĞİŞİKLİK BURADA +++++++++++++++++++
        // Sadece status'ü güncellemek yerine, backend'den gelen
        // tüm güncel kullanıcı verisini (yeni limitler dahil) UserSession'a kaydediyoruz.
        // Bu, anlık olarak limitlerin güncellenmesini sağlar.
        UserSession.storeLoginData(responseData);
        // +++++++++++++++++++++++++++++++++++++++++++++++++++++++
        
        return true;
      }
      debugPrint("Backend doğrulama hatası (${response.statusCode}): ${response.body}");
      return false;
    } catch (e) {
      debugPrint("Backend doğrulama network hatası: $e");
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
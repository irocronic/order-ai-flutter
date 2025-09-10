// lib/services/connectivity_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Uygulama genelinde internet bağlantısını dinleyen ve durumunu bildiren servis.
class ConnectivityService {
  // Singleton pattern
  ConnectivityService._privateConstructor();
  static final ConnectivityService instance = ConnectivityService._privateConstructor();

  final Connectivity _connectivity = Connectivity();
  
  // DEĞİŞİKLİK: StreamSubscription tipi List<ConnectivityResult> yerine ConnectivityResult oldu.
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  Timer? _webHeartbeatTimer;

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier(true);
  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;

    // Durum değişikliklerini dinle
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    // Başlangıç durumunu hemen kontrol et
    _performRealConnectivityCheck();
    // Sadece web platformunda periyodik kontrolü başlat
    if (kIsWeb) {
      _startPeriodicWebCheck();
    }
    
    _isInitialized = true;
    debugPrint("[ConnectivityService] Başlatıldı.");
  }
  
  void _startPeriodicWebCheck() {
    _webHeartbeatTimer?.cancel();
    // Web'de bağlantıyı periyodik olarak kontrol et
    _webHeartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!_isInitialized) {
        timer.cancel();
        return;
      }
      _performRealConnectivityCheck();
    });
  }

  // DEĞİŞİKLİK: Metodun parametresi List<ConnectivityResult> yerine ConnectivityResult oldu.
  void _updateConnectionStatus(ConnectivityResult result) async {
    _performRealConnectivityCheck();
  }

  /// Asıl bağlantı kontrolünü yapan metot.
  Future<void> _performRealConnectivityCheck() async {
    bool wasOnline = isOnlineNotifier.value;
    bool isNowOnline;
    if (kIsWeb) {
      // Web için, bilinen bir adrese HEAD isteği atarak gerçek bağlantıyı test et.
      isNowOnline = await _checkWebConnectivity();
    } else {
      // Mobil için, internet_connection_checker daha güvenilirdir.
      isNowOnline = await InternetConnectionChecker().hasConnection;
    }

    if (wasOnline != isNowOnline) {
      debugPrint("[ConnectivityService] Bağlantı durumu değişti -> ${isNowOnline ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI'}");
      isOnlineNotifier.value = isNowOnline;
    }
  }

  /// Web için internet erişimini test eden özel metot.
  /// Google yerine kendi backend sunucumuza hafif bir HEAD isteği atar.
  Future<bool> _checkWebConnectivity() async {
    try {
      // Django projesindeki root path'e (örn: 'https://example.com/') bir istek atıyoruz.
      // Bu, sadece sunucunun ayakta olup olmadığını kontrol eder.
      final url = Uri.parse(ApiService.baseUrl.replaceAll('/api', '/'));
      // Ana adrese istek at
      await http.head(url).timeout(const Duration(seconds: 4));
      debugPrint("[ConnectivityService-WebCheck] Backend'e ulaşıldı (çevrimiçi).");
      return true;
    } catch (e) {
      debugPrint("[ConnectivityService-WebCheck] Backend'e ulaşılamıyor (çevrimdışı kabul ediliyor): $e");
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription.cancel();
    _webHeartbeatTimer?.cancel();
    isOnlineNotifier.dispose();
    _isInitialized = false;
    debugPrint("[ConnectivityService] Durduruldu.");
  }
}
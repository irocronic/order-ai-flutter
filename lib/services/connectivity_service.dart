// lib/services/connectivity_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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

  /// ÇÖZÜM: Eksik olan `isOnline` property'si eklendi
  /// Bu property, mevcut çevrimiçi durumunu döndürür
  Future<bool> get isOnline async {
    if (kIsWeb) {
      return await _checkWebConnectivity();
    } else {
      return await InternetConnectionChecker().hasConnection;
    }
  }

  /// Senkron erişim için mevcut durumu döndüren property
  /// Bu, sadece son bilinen durumu döndürür ve asenkron kontrol yapmaz
  bool get isCurrentlyOnline => isOnlineNotifier.value;

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
    debugPrint("[ConnectivityService] ${_getLocalizedText('connectivity_service_started')}");
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
      debugPrint("[ConnectivityService] ${_getLocalizedText('connection_status_changed')} -> ${isNowOnline ? _getLocalizedText('online') : _getLocalizedText('offline')}");
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
      debugPrint("[ConnectivityService-WebCheck] ${_getLocalizedText('backend_connected')}");
      return true;
    } catch (e) {
      debugPrint("[ConnectivityService-WebCheck] ${_getLocalizedText('backend_connection_failed')}: $e");
      return false;
    }
  }

  /// ÇÖZÜM: Ek yardımcı metot - bağlantı durumunu manuel olarak yenile
  Future<void> refreshConnectionStatus() async {
    await _performRealConnectivityCheck();
  }

  void dispose() {
    _connectivitySubscription.cancel();
    _webHeartbeatTimer?.cancel();
    isOnlineNotifier.dispose();
    _isInitialized = false;
    debugPrint("[ConnectivityService] ${_getLocalizedText('connectivity_service_stopped')}");
  }

  // Basit çeviri metodu (gerçek uygulamada context gerekebilir)
  String _getLocalizedText(String key) {
    // Bu metod gerçek uygulamada context ile AppLocalizations kullanacak
    // Şimdilik basit bir mapping yapıyoruz
    final translations = {
      'connectivity_service_started': 'Başlatıldı.',
      'connection_status_changed': 'Bağlantı durumu değişti',
      'online': 'ÇEVRİMİÇİ',
      'offline': 'ÇEVRİMDIŞI', 
      'backend_connected': 'Backend\'e ulaşıldı (çevrimiçi).',
      'backend_connection_failed': 'Backend\'e ulaşılamıyor (çevrimdışı kabul ediliyor)',
      'connectivity_service_stopped': 'Durduruldu.',
    };
    return translations[key] ?? key;
  }
}
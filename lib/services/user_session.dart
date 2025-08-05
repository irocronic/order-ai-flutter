// lib/services/user_session.dart

import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import '../models/kds_screen_model.dart';
import 'api_service.dart';

// YENİ: Abonelik limitlerini bir arada tutan yardımcı sınıf.
class SubscriptionLimits {
  final int maxTables;
  final int maxKdsScreens;
  final int maxCategories;
  final int maxMenuItems;
  final int maxVariants;
  final int maxStaff;

  SubscriptionLimits({
    required this.maxTables,
    required this.maxKdsScreens,
    required this.maxCategories,
    required this.maxMenuItems,
    required this.maxVariants,
    required this.maxStaff,
  });
}

class UserSession {
  // Mevcut Değişkenler
  static String _token = '';
  static String _userType = '';
  static List<String> _staffPermissions = [];
  static List<String> _notificationPermissions = [];
  static int? _businessId;
  static bool _isSetupComplete = false;
  static String _username = '';
  static int? _userId;
  static List<KdsScreenModel> _userAccessibleKdsScreens = [];
  static String? _profileImageUrl;
  static String? _currencyCode;
  static String? _subscriptionStatus;
  static String? _trialEndsAt;

  // Statik limit değişkenleri, doğrudan erişim için hala tutulabilir.
  static int _maxTables = 10;
  static int _maxKdsScreens = 2;
  static int _maxCategories = 4;
  static int _maxMenuItems = 20;
  static int _maxVariants = 50;
  static int _maxStaff = 2;

  static final ValueNotifier<String?> subscriptionStatusNotifier =
      ValueNotifier(_subscriptionStatus);

  // === YENİ: Abonelik limitlerini tutacak reaktif notifier ===
  static final ValueNotifier<SubscriptionLimits> limitsNotifier = ValueNotifier(
    SubscriptionLimits( // Başlangıç/varsayılan değerler
      maxTables: 10,
      maxKdsScreens: 2,
      maxCategories: 4,
      maxMenuItems: 20,
      maxVariants: 50,
      maxStaff: 2,
    ),
  );
  // ==========================================================

  // GETTER'LAR
  static String get token => _token;
  static String get userType => _userType;
  static List<String> get staffPermissions => _staffPermissions;
  static List<String> get notificationPermissions => _notificationPermissions;
  static int? get businessId => _businessId;
  static bool get isSetupComplete => _isSetupComplete;
  static String get username => _username;
  static int? get userId => _userId;
  static List<KdsScreenModel> get userAccessibleKdsScreens =>
      _userAccessibleKdsScreens;
  static String? get profileImageUrl => _profileImageUrl;
  static String? get currencyCode => _currencyCode;
  static String? get subscriptionStatus => _subscriptionStatus;
  static String? get trialEndsAt => _trialEndsAt;

  // Statik getter'lar uyumluluk için korunuyor.
  static int get maxTables => _maxTables;
  static int get maxKdsScreens => _maxKdsScreens;
  static int get maxCategories => _maxCategories;
  static int get maxMenuItems => _maxMenuItems;
  static int get maxVariants => _maxVariants;
  static int get maxStaff => _maxStaff;

  static void updateProfileImageUrl(String? url) {
    _profileImageUrl = url;
    debugPrint("[UserSession] Profil fotoğrafı URL'si güncellendi: $url");
  }

  static void updateCurrencyCode(String? newCurrencyCode) {
    _currencyCode = newCurrencyCode;
    debugPrint("[UserSession] İşletme para birimi güncellendi: $_currencyCode");
  }

  static void storeLoginData(Map<String, dynamic> loginOrTokenPayload) {
    _token = loginOrTokenPayload['access'] ?? loginOrTokenPayload['token'] ?? _token;
    _userType = loginOrTokenPayload['user_type'] ?? _userType;
    _businessId = loginOrTokenPayload['business_id'] as int? ?? _businessId;
    _isSetupComplete =
        loginOrTokenPayload['is_setup_complete'] as bool? ?? _isSetupComplete;
    _username = loginOrTokenPayload['username'] ?? _username;
    _userId = loginOrTokenPayload['user_id'] as int? ?? _userId;
    _profileImageUrl =
        loginOrTokenPayload['profile_image_url'] as String? ?? _profileImageUrl;
    _currencyCode = loginOrTokenPayload['currency_code'] as String? ?? 'TRY';
    _subscriptionStatus =
        loginOrTokenPayload['subscription_status'] as String? ?? _subscriptionStatus;
    _trialEndsAt =
        loginOrTokenPayload['trial_ends_at'] as String? ?? _trialEndsAt;

    subscriptionStatusNotifier.value = _subscriptionStatus;

    // === GÜNCELLENDİ: Abonelik Limitlerini Yükleme ve Notifier'ı Tetikleme ===
    if (loginOrTokenPayload['subscription'] != null &&
        loginOrTokenPayload['subscription'] is Map) {
      final subData = loginOrTokenPayload['subscription'];
      _maxTables = subData['max_tables'] ?? 10;
      _maxKdsScreens = subData['max_kds_screens'] ?? 2;
      _maxCategories = subData['max_categories'] ?? 4;
      _maxMenuItems = subData['max_menu_items'] ?? 20;
      _maxVariants = subData['max_variants'] ?? 50;
      _maxStaff = subData['max_staff'] ?? 2;
    } else {
      // Abonelik bilgisi yoksa varsayılan değerlere dön
      _maxTables = 10;
      _maxKdsScreens = 2;
      _maxCategories = 4;
      _maxMenuItems = 20;
      _maxVariants = 50;
      _maxStaff = 2;
    }
    
    // Yeni limitlerle notifier'ın değerini güncelle. Bu, dinleyen tüm widget'ları tetikleyecektir.
    limitsNotifier.value = SubscriptionLimits(
      maxTables: _maxTables,
      maxKdsScreens: _maxKdsScreens,
      maxCategories: _maxCategories,
      maxMenuItems: _maxMenuItems,
      maxVariants: _maxVariants,
      maxStaff: _maxStaff,
    );
    // =======================================================================

    if (loginOrTokenPayload['staff_permissions'] is List) {
      _staffPermissions = List<String>.from(
          loginOrTokenPayload['staff_permissions'].map((p) => p.toString()));
    } else if (loginOrTokenPayload['staff_permissions'] == null &&
        _token.isNotEmpty &&
        _userType != 'business_owner') {
      _staffPermissions = [];
    }
    if (loginOrTokenPayload['notification_permissions'] is List) {
      _notificationPermissions = List<String>.from(
          loginOrTokenPayload['notification_permissions'].map((p) => p.toString()));
    } else if (loginOrTokenPayload['notification_permissions'] == null &&
        _token.isNotEmpty) {
      _notificationPermissions = [];
    }
    if (loginOrTokenPayload['accessible_kds_screens_details'] is List) {
      try {
        _userAccessibleKdsScreens =
            (loginOrTokenPayload['accessible_kds_screens_details'] as List)
                .map((kdsJson) =>
                    KdsScreenModel.fromJson(kdsJson as Map<String, dynamic>))
                .toList();
      } catch (e) {
        debugPrint("[UserSession] KDS ekran detayları parse edilirken hata: $e");
        _userAccessibleKdsScreens = [];
      }
    } else {
      _userAccessibleKdsScreens = [];
    }
  }

  static void clearSession() {
    _token = '';
    _userType = '';
    _staffPermissions = [];
    _notificationPermissions = [];
    _businessId = null;
    _isSetupComplete = false;
    _username = '';
    _userId = null;
    _userAccessibleKdsScreens = [];
    _profileImageUrl = null;
    _currencyCode = null;
    _subscriptionStatus = null;
    _trialEndsAt = null;
    subscriptionStatusNotifier.value = null;

    // === GÜNCELLENDİ: Oturum kapatıldığında limitleri ve notifier'ı varsayılana döndür ===
    _maxTables = 10;
    _maxKdsScreens = 2;
    _maxCategories = 4;
    _maxMenuItems = 20;
    _maxVariants = 50;
    _maxStaff = 2;
    limitsNotifier.value = SubscriptionLimits(
      maxTables: _maxTables,
      maxKdsScreens: _maxKdsScreens,
      maxCategories: _maxCategories,
      maxMenuItems: _maxMenuItems,
      maxVariants: _maxVariants,
      maxStaff: _maxStaff,
    );
    // ===================================================================================

    debugPrint("UserSession Temizlendi.");
  }

  static bool hasPagePermission(String permissionKey) {
    if (_userType == 'business_owner') return true;
    return _staffPermissions.contains(permissionKey);
  }

  static bool hasNotificationPermission(String eventTypeKey) {
    if (_userType == 'business_owner') {
      if (_notificationPermissions.isEmpty) return true;
      return _notificationPermissions.contains(eventTypeKey);
    }
    if (_notificationPermissions.isEmpty) {
      return false;
    }
    return _notificationPermissions.contains(eventTypeKey);
  }

  static void updateSubscriptionStatus(String? newStatus, String? newTrialEndsAt) {
    _trialEndsAt = newTrialEndsAt;
    _subscriptionStatus = newStatus;
    subscriptionStatusNotifier.value = newStatus;
    debugPrint(
        "[UserSession] Abonelik durumu harici olarak güncellendi: $_subscriptionStatus");
  }

  static Future<void> refreshSessionData() async {
    if (token.isEmpty) return;
    try {
      final refreshedData = await ApiService.fetchMyUser(token);
      refreshedData['access'] = token;
      storeLoginData(refreshedData);
      debugPrint("[UserSession] Oturum verileri başarıyla yenilendi.");
    } catch (e) {
      debugPrint("[UserSession] Oturum verileri yenilenirken hata: $e");
    }
  }
}
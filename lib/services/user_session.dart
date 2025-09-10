// lib/services/user_session.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kds_screen_model.dart';
import 'socket_service.dart';
import 'connection_manager.dart';
import 'global_notification_handler.dart';
import '../screens/login_screen.dart';

// Abonelik limitlerini tutmak için basit bir sınıf
class SubscriptionLimits {
  final int maxTables;
  final int maxStaff;
  final int maxKdsScreens;
  final int maxCategories;
  final int maxMenuItems;
  final int maxVariants;

  const SubscriptionLimits({
    this.maxTables = 10,
    this.maxStaff = 2,
    this.maxKdsScreens = 1,
    this.maxCategories = 5,
    this.maxMenuItems = 20,
    this.maxVariants = 40,
  });

  factory SubscriptionLimits.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SubscriptionLimits();
    }
    return SubscriptionLimits(
      maxTables: json['max_tables'] ?? 10,
      maxStaff: json['max_staff'] ?? 2,
      maxKdsScreens: json['max_kds_screens'] ?? 1,
      maxCategories: json['max_categories'] ?? 5,
      maxMenuItems: json['max_menu_items'] ?? 20,
      maxVariants: json['max_variants'] ?? 50,
    );
  }
}

class UserSession {
  static SharedPreferences? _preferences;

  // Anahtar isimleri
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _userTypeKey = 'user_type';
  static const _businessIdKey = 'business_id';
  static const _isSetupCompleteKey = 'is_setup_complete';
  static const _staffPermissionsKey = 'staff_permissions';
  static const _notificationPermissionsKey = 'notification_permissions';
  static const _accessibleKdsScreensKey = 'accessible_kds_screens';
  static const _profileImageUrlKey = 'profile_image_url';
  static const _subscriptionStatusKey = 'subscription_status';
  static const _subscriptionLimitsKey = 'subscription_limits';
  static const _currencyCodeKey = 'currency_code';
  static const _trialEndsAtKey = 'trial_ends_at';

  // Oturum verileri
  static String _token = '';
  static String _refreshToken = '';
  static int? _userId;
  static String _username = '';
  static String _userType = '';
  static int? _businessId;
  static bool _isSetupComplete = false;
  static List<String> _staffPermissions = [];
  static List<String> _notificationPermissions = [];
  static List<KdsScreenModel> _userAccessibleKdsScreens = [];
  static String? _profileImageUrl;
  static String? _subscriptionStatus;
  static String? _currencyCode;
  static String? _trialEndsAt;

  // ValueNotifier'lar
  static final ValueNotifier<SubscriptionLimits> limitsNotifier = ValueNotifier(const SubscriptionLimits());
  static final ValueNotifier<String?> subscriptionStatusNotifier = ValueNotifier(null);

  // Getter'lar
  static String get token => _token;
  static String get refreshToken => _refreshToken;
  static int? get userId => _userId;
  static String get username => _username;
  static String get userType => _userType;
  static int? get businessId => _businessId;
  static bool get isSetupComplete => _isSetupComplete;
  static List<String> get staffPermissions => _staffPermissions;
  static List<String> get notificationPermissions => _notificationPermissions;
  static List<KdsScreenModel> get userAccessibleKdsScreens => _userAccessibleKdsScreens;
  static String? get profileImageUrl => _profileImageUrl;
  static String? get subscriptionStatus => _subscriptionStatus;
  static String? get currencyCode => _currencyCode;
  static String? get trialEndsAt => _trialEndsAt;

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    _loadSessionData();
  }

  static Future<void> storeLoginData(Map<String, dynamic> data) async {
    _token = data['access'] ?? '';
    _refreshToken = data['refresh'] ?? '';
    _userId = data['user_id'];
    _username = data['username'] ?? '';
    _userType = data['user_type'] ?? '';
    _businessId = data['business_id'];
    _isSetupComplete = data['is_setup_complete'] ?? false;
    _profileImageUrl = data['profile_image_url'];
    _subscriptionStatus = data['subscription_status'];
    _currencyCode = data['currency_code'];
    _trialEndsAt = data['trial_ends_at'];

    subscriptionStatusNotifier.value = _subscriptionStatus;

    if (data['staff_permissions'] is List) {
      _staffPermissions = List<String>.from(data['staff_permissions']);
    } else {
      _staffPermissions = [];
    }
    
    if (data['notification_permissions'] is List) {
      _notificationPermissions = List<String>.from(data['notification_permissions']);
    } else {
      _notificationPermissions = [];
    }

    if (data['accessible_kds_screens_details'] is List) {
      try {
        _userAccessibleKdsScreens = (data['accessible_kds_screens_details'] as List)
            .map((kdsJson) => KdsScreenModel.fromJson(kdsJson))
            .toList();
      } catch(e) {
        debugPrint("KDS ekranları parse edilirken hata: $e");
        _userAccessibleKdsScreens = [];
      }
    } else {
      _userAccessibleKdsScreens = [];
    }
    
    if (data['subscription'] is Map<String, dynamic>) {
      limitsNotifier.value = SubscriptionLimits.fromJson(data['subscription']);
    } else {
      limitsNotifier.value = const SubscriptionLimits();
    }

    // Verileri SharedPreferences'e kaydet
    await _preferences?.setString(_tokenKey, _token);
    await _preferences?.setString(_refreshTokenKey, _refreshToken);
    await _preferences?.setInt(_userIdKey, _userId ?? 0);
    await _preferences?.setString(_usernameKey, _username);
    await _preferences?.setString(_userTypeKey, _userType);
    if (_businessId != null) {
      await _preferences?.setInt(_businessIdKey, _businessId!);
    } else {
      await _preferences?.remove(_businessIdKey);
    }
    await _preferences?.setBool(_isSetupCompleteKey, _isSetupComplete);
    await _preferences?.setStringList(_staffPermissionsKey, _staffPermissions);
    await _preferences?.setStringList(_notificationPermissionsKey, _notificationPermissions);
    if (_profileImageUrl != null) {
      await _preferences?.setString(_profileImageUrlKey, _profileImageUrl!);
    } else {
      await _preferences?.remove(_profileImageUrlKey);
    }
    if (_subscriptionStatus != null) {
      await _preferences?.setString(_subscriptionStatusKey, _subscriptionStatus!);
    } else {
      await _preferences?.remove(_subscriptionStatusKey);
    }
    if (data['subscription'] is Map) {
      await _preferences?.setString(_subscriptionLimitsKey, jsonEncode(data['subscription']));
    } else {
      await _preferences?.remove(_subscriptionLimitsKey);
    }
    if (_currencyCode != null) {
      await _preferences?.setString(_currencyCodeKey, _currencyCode!);
    } else {
      await _preferences?.remove(_currencyCodeKey);
    }
    if (_trialEndsAt != null) {
      await _preferences?.setString(_trialEndsAtKey, _trialEndsAt!);
    } else {
      await _preferences?.remove(_trialEndsAtKey);
    }
  }

  static void _loadSessionData() {
    _token = _preferences?.getString(_tokenKey) ?? '';
    _refreshToken = _preferences?.getString(_refreshTokenKey) ?? '';
    _userId = _preferences?.getInt(_userIdKey);
    _username = _preferences?.getString(_usernameKey) ?? '';
    _userType = _preferences?.getString(_userTypeKey) ?? '';
    _businessId = _preferences?.getInt(_businessIdKey);
    _isSetupComplete = _preferences?.getBool(_isSetupCompleteKey) ?? false;
    _staffPermissions = _preferences?.getStringList(_staffPermissionsKey) ?? [];
    _notificationPermissions = _preferences?.getStringList(_notificationPermissionsKey) ?? [];
    _profileImageUrl = _preferences?.getString(_profileImageUrlKey);
    _subscriptionStatus = _preferences?.getString(_subscriptionStatusKey);
    _currencyCode = _preferences?.getString(_currencyCodeKey);
    _trialEndsAt = _preferences?.getString(_trialEndsAtKey);

    subscriptionStatusNotifier.value = _subscriptionStatus;

    final limitsJsonString = _preferences?.getString(_subscriptionLimitsKey);
    if (limitsJsonString != null) {
      try {
        limitsNotifier.value = SubscriptionLimits.fromJson(jsonDecode(limitsJsonString));
      } catch (e) {
        limitsNotifier.value = const SubscriptionLimits();
      }
    } else {
      limitsNotifier.value = const SubscriptionLimits();
    }
  }

  // 🆕 GÜÇLENDIRILEN clearSession metodunu ekle
  static Future<void> clearSession() async {
    debugPrint('[UserSession] Oturum temizleme başlatılıyor...');
    
    // 🆕 CRITICAL: SocketService'i kesin olarak temizle
    SocketService.blockInitialization();
    
    // Kısa bir bekleme ver ki blocking etkili olsun
    await Future.delayed(const Duration(milliseconds: 100));
    
    SocketService.disposeInstance();
    
    // Memory'deki tüm değişkenleri temizle
    _token = '';
    _refreshToken = '';
    _userId = null;
    _username = '';
    _userType = '';
    _businessId = null;
    _isSetupComplete = false;
    _staffPermissions = [];
    _notificationPermissions = [];
    _userAccessibleKdsScreens = [];
    _profileImageUrl = null;
    _subscriptionStatus = null;
    _currencyCode = null;
    _trialEndsAt = null;
    limitsNotifier.value = const SubscriptionLimits();
    subscriptionStatusNotifier.value = null;

    // SharedPreferences'i temizle
    try {
      await _preferences?.clear();
    } catch (e) {
      debugPrint('[UserSession] SharedPreferences temizleme hatası: $e');
    }
    
    debugPrint('[UserSession] Oturum temizlendi.');
    
    // 🆕 ENHANCED: Kısa delay sonra initialization'a izin ver
    Future.delayed(const Duration(milliseconds: 500), () {
      SocketService.allowInitialization();
      debugPrint('[UserSession] SocketService initialization yeniden etkinleştirildi.');
    });
  }

  static bool hasPagePermission(String key) {
    if (_userType == 'business_owner') return true;
    return _staffPermissions.contains(key);
  }

  static bool hasNotificationPermission(String eventTypeKey) {
    if (_userType == 'business_owner' || _userType == 'admin') return true;
    return _notificationPermissions.contains(eventTypeKey);
  }

  static Future<void> updateAccessToken(String newAccessToken) async {
    await _preferences?.setString(_tokenKey, newAccessToken);
    _token = newAccessToken;
  }

  static Future<void> updateTokens({required String accessToken, String? refreshToken}) async {
    await _preferences?.setString(_tokenKey, accessToken);
    _token = accessToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _preferences?.setString(_refreshTokenKey, refreshToken);
      _refreshToken = refreshToken;
      debugPrint("[UserSession] Access ve Refresh token güncellendi.");
    } else {
      debugPrint("[UserSession] Sadece Access token güncellendi.");
    }
  }

  static Future<void> updateProfileImageUrl(String? url) async {
    _profileImageUrl = url;
    if (url != null) {
      await _preferences?.setString(_profileImageUrlKey, url);
    } else {
      await _preferences?.remove(_profileImageUrlKey);
    }
  }

  static Future<void> updateCurrencyCode(String? code) async {
    _currencyCode = code;
    if (code != null) {
      await _preferences?.setString(_currencyCodeKey, code);
    } else {
      await _preferences?.remove(_currencyCodeKey);
    }
  }
}

// 🆕 GÜÇLENDIRILEN GLOBAL LOGOUT CLASS
class GlobalLogout {
  static Future<void> performGlobalLogout(BuildContext? context) async {
    debugPrint('[GlobalLogout] Kapsamlı logout işlemi başlatılıyor...');
    
    try {
      // 🔧 STEP 1: SocketService'i tamamen engelle ve temizle
      SocketService.blockInitialization();
      debugPrint('[GlobalLogout] SocketService initialization engellendi');
      
      // 🆕 CRITICAL: Disposal'ın tamamlanması için bekle
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 🔧 STEP 2: Diğer servisleri temizle
      try {
        ConnectionManager().stopMonitoring();
        debugPrint('[GlobalLogout] ConnectionManager durduruldu');
      } catch (e) {
        debugPrint('[GlobalLogout] ConnectionManager durdurma hatası: $e');
      }
      
      try {
        GlobalNotificationHandler.cleanup();
        debugPrint('[GlobalLogout] GlobalNotificationHandler temizlendi');
      } catch (e) {
        debugPrint('[GlobalLogout] GlobalNotificationHandler temizleme hatası: $e');
      }
      
      // 🔧 STEP 3: SocketService'i tamamen dispose et
      try {
        SocketService.disposeInstance();
        debugPrint('[GlobalLogout] SocketService disposed');
      } catch (e) {
        debugPrint('[GlobalLogout] SocketService dispose hatası: $e');
      }
      
      // 🆕 CRITICAL: Disposal'ın etkili olması için uzun bekleme
      await Future.delayed(const Duration(milliseconds: 800)); // 500ms'den 800ms'ye çıkarıldı
      
      // 🔧 STEP 4: UserSession'ı temizle (içinde SocketService allowInitialization var)
      await UserSession.clearSession();
      debugPrint('[GlobalLogout] UserSession temizlendi');
      
      debugPrint('[GlobalLogout] Tüm servisler temizlendi, yönlendirme yapılıyor...');
      
      // 🔧 STEP 5: Login ekranına yönlendir
      if (context != null && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      
      debugPrint('[GlobalLogout] Logout tamamlandı ve LoginScreen\'e yönlendirildi.');
      
    } catch (e) {
      debugPrint('[GlobalLogout] Logout sırasında hata: $e');
      
      // 🔧 CRITICAL FIX: Hata durumunda da flag'i temizle
      try {
        SocketService.allowInitialization();
        debugPrint('[GlobalLogout] Hata durumunda SocketService initialization etkinleştirildi');
      } catch (socketError) {
        debugPrint('[GlobalLogout] SocketService allowInitialization hatası: $socketError');
      }
      
      // Yine de login ekranına yönlendir
      if (context != null && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
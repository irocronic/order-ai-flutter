// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io'; // SocketException için
import 'dart:async'; // TimeoutException için
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'api_exception.dart'; // Özel exception sınıfı
import 'user_session.dart';
import 'notification_center.dart';

class ApiService {
  static final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'https://order-ai-7bd2c97ec9ef.herokuapp.com/api';

  static Uri getUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      return Uri.parse('$baseUrl$endpoint');
    }
    return Uri.parse('$baseUrl/$endpoint');
  }

  // 🆕 CRITICAL: Her HTTP request öncesi token kontrolü
  static Future<Map<String, String>> _getValidHeaders() async {
    // Token kontrolü
    if (UserSession.token.isEmpty) {
      throw Exception('Token bulunamadı');
    }
    
    // Token süresi kontrolü
    bool isExpired = false;
    try {
      isExpired = JwtDecoder.isExpired(UserSession.token);
    } catch (e) {
      debugPrint('[ApiService] Token parse error: $e');
      isExpired = true;
    }
    
    // Expired ise yenile
    if (isExpired) {
      debugPrint('[ApiService] Token expired, refreshing...');
      if (UserSession.refreshToken.isEmpty) {
        throw Exception('Refresh token bulunamadı');
      }
      
      try {
        final newTokens = await refreshToken(UserSession.refreshToken);
        final newAccess = newTokens['access'];
        final newRefresh = newTokens['refresh'] ?? UserSession.refreshToken;
        
        if (newAccess != null) {
          await UserSession.updateTokens(accessToken: newAccess, refreshToken: newRefresh);
          debugPrint('[ApiService] Token successfully refreshed');
        } else {
          throw Exception('Token refresh response invalid');
        }
      } catch (e) {
        debugPrint('[ApiService] Token refresh failed: $e');
        // Logout trigger
        NotificationCenter.instance.postNotification('auth_refresh_failed', {
          'reason': 'api_token_refresh_failed',
          'error': e.toString()
        });
        throw Exception('Token refresh failed: $e');
      }
    }
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${UserSession.token}',
    };
  }
  
  // 🆕 Tüm HTTP metodlarını güncelle:
  static Future<http.Response> _makeRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
    int retryCount = 0,
  }) async {
    try {
      final headers = await _getValidHeaders();
      
      http.Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(Uri.parse(url), headers: headers);
          break;
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PATCH':
          response = await http.patch(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(Uri.parse(url), headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
      
      // 401 durumunda bir kez daha token refresh dene
      if (response.statusCode == 401 && retryCount == 0) {
        debugPrint('[ApiService] 401 received, forcing token refresh and retry...');
        
        // Force token refresh
        if (UserSession.refreshToken.isNotEmpty) {
          try {
            final newTokens = await refreshToken(UserSession.refreshToken);
            final newAccess = newTokens['access'];
            if (newAccess != null) {
              await UserSession.updateTokens(accessToken: newAccess);
              debugPrint('[ApiService] Force token refresh successful, retrying request...');
              return _makeRequest(method, url, body: body, retryCount: 1);
            }
          } catch (e) {
            debugPrint('[ApiService] Force token refresh failed: $e');
          }
        }
        
        // Token refresh başarısızsa logout trigger
        NotificationCenter.instance.postNotification('auth_refresh_failed', {
          'reason': 'api_401_token_refresh_failed'
        });
      }
      
      return response;
    } catch (e) {
      debugPrint('[ApiService] Request failed: $e');
      rethrow;
    }
  }

  static Future<http.Response> postJson(String endpoint, Map<String, dynamic> payload, String token) {
    final url = getUrl(endpoint);
    return http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = getUrl('/token/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final responseBody = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> responseData = responseBody.isNotEmpty ? jsonDecode(responseBody) : {};

      if (response.statusCode == 200) {
        return responseData;
      } else {
        String detail = responseData['detail'] ?? 'Bilinmeyen bir giriş hatası.';
        String code = responseData['code'] ?? 'generic_error';
        throw ApiException(detail, code: code, statusCode: response.statusCode);
      }
    } on SocketException {
      throw ApiException('İnternet bağlantısı kurulamadı. Lütfen ağ ayarlarınızı kontrol edin.', code: 'network_error');
    } on TimeoutException {
      throw ApiException('Sunucuya bağlanırken zaman aşımı yaşandı. Lütfen daha sonra tekrar deneyin.', code: 'timeout_error');
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('Login sırasında beklenmedik hata: $e');
      throw ApiException('Giriş sırasında beklenmedik bir sorun oluştu.', code: 'unknown_error');
    }
  }
  
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final url = getUrl('/token/refresh/');
    debugPrint("ApiService: Refreshing token...");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint("ApiService: Token successfully refreshed.");
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw ApiException(
          'Oturum süresi doldu. Lütfen tekrar giriş yapın.', 
          code: 'token_not_valid', 
          statusCode: response.statusCode
        );
      }
    } on SocketException {
      throw ApiException('İnternet bağlantısı kurulamadı.', code: 'network_error');
    } on TimeoutException {
      throw ApiException('Sunucuya bağlanırken zaman aşımı yaşandı.', code: 'timeout_error');
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('Token refresh sırasında beklenmedik hata: $e');
      throw ApiException('Oturum yenilenirken bir sorun oluştu.', code: 'unknown_error');
    }
  }

  static Future<Map<String, dynamic>> register(String username, String email, String password, String userType) async {
    final url = getUrl('/register/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'user_type': userType,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('Register API hatası (${response.statusCode}): $errorBody');
        String errorMessage = 'Kayıt başarısız: ${response.statusCode}';
        try {
          Map<String, dynamic> errorData = jsonDecode(errorBody);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          } else if (errorData.keys.isNotEmpty) {
            String firstErrorKey = errorData.keys.first;
            if (errorData[firstErrorKey] is List && errorData[firstErrorKey].isNotEmpty) {
              errorMessage = '${firstErrorKey.capitalize()}: ${errorData[firstErrorKey][0]}';
            } else if (errorData[firstErrorKey] is String) {
              errorMessage = '${firstErrorKey.capitalize()}: ${errorData[firstErrorKey]}';
            } else {
              errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
            }
          } else {
            errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
          }
        } catch (jsonErr) {
          errorMessage = errorBody.isNotEmpty ? errorBody : 'Sunucudan anlaşılmayan bir yanıt alındı.';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Register sırasında genel hata: $e');
      if (e is Exception) {
        throw e;
      }
      throw Exception('Kayıt sırasında bir sorun oluştu. Lütfen internet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.');
    }
  }

  static Future<Map<String, dynamic>> fetchMyUser(String token) async {
    final url = getUrl('/account/');
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('FetchMyUser API hatası (${response.statusCode}): $errorBody');
        if (response.statusCode == 404) {
          throw Exception('Kullanıcı hesap bilgisi bulunamadı.');
        }
        throw Exception('Kullanıcı verisi alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('FetchMyUser sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Hesap bilgileri alınırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> updateMyUser(String token, Map<String, dynamic> data) async {
    final url = getUrl('/account/');
    debugPrint("ApiService: updateMyUser payload: ${jsonEncode(data)}");
    try {
      final response = await _makeRequest('PUT', url.toString(), body: data);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('UpdateMyUser API hatası (${response.statusCode}): $errorBody');
        String errorMessage = 'Güncelleme başarısız: ${response.statusCode}';
        try {
          Map<String, dynamic> errorData = jsonDecode(errorBody);
          if (errorData.keys.isNotEmpty) {
            String firstErrorKey = errorData.keys.first;
            if (errorData[firstErrorKey] is List && errorData[firstErrorKey].isNotEmpty) {
              String friendlyKey = firstErrorKey.replaceAll('_', ' ').capitalize();
              errorMessage = '${friendlyKey}: ${errorData[firstErrorKey][0]}';
            } else if (errorData[firstErrorKey] is String) {
              String friendlyKey = firstErrorKey.replaceAll('_', ' ').capitalize();
              errorMessage = '${friendlyKey}: ${errorData[firstErrorKey]}';
            } else {
              errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
            }
          } else {
            errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
          }
        } catch (jsonErr) {
          errorMessage = errorBody.isNotEmpty ? errorBody : 'Sunucudan anlaşılmayan bir yanıt alındı.';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('UpdateMyUser sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Hesap bilgileri güncellenirken bir sorun oluştu.');
    }
  }

  static Future<List<dynamic>> getStaffList(String token) async {
    final url = getUrl('/staff-users/');
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Personel listesi alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('getStaffList sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Personel listesi alınırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> createStaff(String token, Map<String, dynamic> staffData) async {
    final url = getUrl('/staff-users/');
    debugPrint("ApiService: createStaff payload: ${jsonEncode(staffData)}");
    try {
      final response = await _makeRequest('POST', url.toString(), body: staffData);
      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('createStaff API Error (${response.statusCode}): $errorBody');
        throw Exception('Personel oluşturulamadı: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('createStaff sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Personel oluşturulurken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> updateStaff(String token, int staffId, Map<String, dynamic> staffData) async {
    final url = getUrl('/staff-users/$staffId/');
    debugPrint("ApiService: updateStaff payload for staff $staffId: ${jsonEncode(staffData)}");
    try {
      final response = await _makeRequest('PUT', url.toString(), body: staffData);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('updateStaff API Error (${response.statusCode}): $errorBody');
        throw Exception('Personel güncellenemedi: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('updateStaff sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Personel güncellenirken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> updateStaffPermissions(String token, int staffId, List<String> permissions) async {
    final url = getUrl('/staff-users/$staffId/permissions/');
    debugPrint("ApiService: updateStaffPermissions payload for staff $staffId: ${jsonEncode({'staff_permissions': permissions})}");
    try {
      final response = await _makeRequest('PUT', url.toString(), body: {'staff_permissions': permissions});
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Personel ekran izinleri güncellenemedi: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('updateStaffPermissions sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Personel ekran izinleri güncellenirken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> updateStaffNotificationPermissions(String token, int staffId, List<String> notificationPermissions) async {
    final url = getUrl('/staff-users/$staffId/notification-permissions/');
    debugPrint("ApiService: updateStaffNotificationPermissions payload for staff $staffId: ${jsonEncode({'notification_permissions': notificationPermissions})}");
    try {
      final response = await _makeRequest('PUT', url.toString(), body: {'notification_permissions': notificationPermissions});
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Personel bildirim izinleri güncellenemedi: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('updateStaffNotificationPermissions sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Personel bildirim izinleri güncellenirken bir sorun oluştu.');
    }
  }

  static Future<void> deleteStaff(String token, int staffId) async {
    final url = getUrl('/staff-users/$staffId/');
    try {
      final response = await _makeRequest('DELETE', url.toString());
      if (response.statusCode != 204) {
        throw Exception('Personel silinemedi: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('deleteStaff sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Personel silinirken bir sorun oluştu.');
    }
  }

  static Future<List<dynamic>> fetchStaffPerformance(
    String token, {
    String? timeRange,
    String? startDate,
    String? endDate,
  }) async {
    Map<String, String> queryParams = {};
    if (timeRange != null && timeRange.isNotEmpty) {
      queryParams['time_range'] = timeRange;
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams['end_date'] = endDate;
    }

    final url = getUrl('/reports/staff-performance/').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    debugPrint("Fetching staff performance from: $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception(
            'Personel performans raporu alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('fetchStaffPerformance sırasında ağ/servis hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Rapor verileri alınırken bir sorun oluştu.');
    }
  }

  static Future<List<dynamic>> fetchDetailedSalesReport(
    String token, {
    String? timeRange,
    String? startDate,
    String? endDate,
  }) async {
    Map<String, String> queryParams = {};
    if (timeRange != null && timeRange != 'custom') {
      queryParams['time_range'] = timeRange;
    }
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      queryParams['end_date'] = endDate;
    }

    final url = getUrl('/reports/detailed-sales/').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    debugPrint("Fetching detailed sales report from: $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception(
            'Detaylı rapor alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('fetchDetailedSalesReport sırasında ağ/servis hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Rapor verileri alınırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> fetchBusinessDetails(String token, int businessId) async {
    final url = getUrl('/businesses/$businessId/');
    debugPrint("Fetching business details from: $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('İşletme detayları alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('fetchBusinessDetails sırasında ağ/servis hatası: $e');
      if (e is Exception) throw e;
      throw Exception('İşletme detayları alınırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> updateBusinessSettings(
    String token,
    int businessId,
    Map<String, dynamic> data,
  ) async {
    final url = getUrl('/businesses/$businessId/');
    debugPrint("ApiService: Updating business $businessId with payload: ${jsonEncode(data)}");
    try {
      final response = await _makeRequest('PATCH', url.toString(), body: data);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('UpdateBusinessSettings API hatası (${response.statusCode}): $errorBody');
        throw Exception('İşletme ayarları güncellenemedi: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('UpdateBusinessSettings sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('İşletme ayarları güncellenirken bir sorun oluştu.');
    }
  }

  static Future<void> markSetupComplete(String token, int businessId) async {
    final url = getUrl('/businesses/$businessId/complete-setup/');
    debugPrint("ApiService: Marking setup complete for business $businessId via $url");
    try {
      final response = await _makeRequest('POST', url.toString());
      if (response.statusCode != 200) {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('markSetupComplete API hatası (${response.statusCode}): $errorBody');
        throw Exception('Kurulum tamamlama durumu güncellenemedi: ${response.statusCode} - $errorBody');
      }
      debugPrint("ApiService: Setup marked complete successfully for business $businessId.");
    } catch (e) {
      debugPrint('markSetupComplete sırasında ağ/servis hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Kurulum tamamlama durumu güncellenirken bir sorun oluştu.');
    }
  }

  static Future<List<dynamic>> fetchTablesForBusiness(String token) async {
    final url = getUrl('/tables/');
    debugPrint("ApiService: Fetching tables from $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Masalar alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('fetchTablesForBusiness sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Masalar alınırken bir sorun oluştu.');
    }
  }

  static Future<List<dynamic>> bulkCreateTables(String token, int businessId, int count) async {
    final url = getUrl('/tables/bulk-create/');
    debugPrint("ApiService: Bulk creating $count tables for business $businessId via $url");
    try {
      final response = await _makeRequest('POST', url.toString(), body: {'count': count});
      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('BulkCreateTables API hatası (${response.statusCode}): $errorBody');
        throw Exception('Masalar oluşturulamadı: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('BulkCreateTables sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Masalar oluşturulurken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> createTableForBusiness(String token, int businessId, int tableNumber) async {
    final url = getUrl('/tables/');
    debugPrint("ApiService: Creating table for business $businessId with number $tableNumber via $url");
    try {
      final response = await _makeRequest('POST', url.toString(), body: {
        'business': businessId,
        'table_number': tableNumber,
      });
      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('createTableForBusiness API hatası (${response.statusCode}): $errorBody');
        try {
          Map<String, dynamic> errorData = jsonDecode(errorBody);
          if (errorData['table_number'] is List && errorData['table_number'].isNotEmpty) {
            throw Exception('Masa eklenemedi: ${errorData['table_number'][0]}');
          } else if (errorData['detail'] is String) {
            throw Exception('Masa eklenemedi: ${errorData['detail']}');
          }
        } catch (_) {}
        throw Exception('Masa eklenemedi: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('createTableForBusiness sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Masa oluşturulurken bir sorun oluştu.');
    }
  }

  static Future<void> deleteTable(String token, int tableId) async {
    final url = getUrl('/tables/$tableId/');
    debugPrint("ApiService: Deleting table $tableId via $url");
    try {
      final response = await _makeRequest('DELETE', url.toString());
      if (response.statusCode != 204) {
        throw Exception('Masa silinemedi: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('deleteTable sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Masa silinirken bir sorun oluştu.');
    }
  }

  static Future<List<dynamic>> fetchCategoriesForBusiness(String token) async {
    final url = getUrl('/categories/');
    debugPrint("ApiService: Fetching categories from $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Kategoriler alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('fetchCategoriesForBusiness sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Kategoriler alınırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> createCategoryForBusiness(
    String token,
    int businessId,
    String name,
    int? parentId,
    String? imageUrl,
    int? kdsScreenId,
    double? kdvRate,
  ) async {
    final url = getUrl('/categories/');
    final Map<String, dynamic> payload = {
      'business': businessId,
      'name': name,
    };
    if (parentId != null) {
      payload['parent'] = parentId;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      payload['image'] = imageUrl;
    }
    if (kdsScreenId != null) {
      payload['assigned_kds'] = kdsScreenId;
    }
    if (kdvRate != null) {
      payload['kdv_rate'] = kdvRate.toStringAsFixed(2);
    }

    debugPrint("ApiService: Creating category with payload: ${jsonEncode(payload)} via $url");
    try {
      final response = await _makeRequest('POST', url.toString(), body: payload);
      final String responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 201) {
        return jsonDecode(responseBody);
      } else {
        debugPrint('createCategoryForBusiness API hatası (${response.statusCode}): $responseBody');
        throw Exception(
            'Kategori oluşturulamadı: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      debugPrint('createCategoryForBusiness sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Kategori oluşturulurken bir sorun oluştu.');
    }
  }

  static Future<void> deleteCategory(String token, int categoryId) async {
    final url = getUrl('/categories/$categoryId/');
    debugPrint("ApiService: Deleting category $categoryId via $url");
    try {
      final response = await _makeRequest('DELETE', url.toString());
      if (response.statusCode != 204) {
        throw Exception('Kategori silinemedi: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('deleteCategory sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Kategori silinirken bir sorun oluştu.');
    }
  }

  // YENİ METOTLAR
  static Future<List<dynamic>> fetchCategoryTemplates() async {
    final url = getUrl('/templates/category-templates/');
    debugPrint("ApiService: Fetching category templates from $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Kategori şablonları alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('fetchCategoryTemplates sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Kategori şablonları alınırken bir sorun oluştu.');
    }
  }

  // GÜNCELLENEN METOT: createCategoriesFromTemplates
  static Future<List<dynamic>> createCategoriesFromTemplates(
    String token, // YENİ: Token parametresi eklendi  
    List<int> templateIds,
    int? assignedKdsId, // YENİ: KDS ID parametresi eklendi
  ) async {
    final url = getUrl('/categories/create-from-template/');
    debugPrint("ApiService: Creating categories from templates with IDs: $templateIds and KDS ID: $assignedKdsId");
    
    // YENİ: Payload KDS ID'sini içerecek şekilde güncellendi
    final Map<String, dynamic> payload = {
      'template_ids': templateIds,
    };
    if (assignedKdsId != null) {
      payload['assigned_kds_id'] = assignedKdsId;
    }

    try {
      // GÜNCELLEME: Artık _makeRequest helper'ını kullanıyoruz
      final response = await _makeRequest(
        'POST',
        url.toString(),
        body: payload,
      );

      final String responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode == 201) {
        return jsonDecode(responseBody);
      } else {
        String errorDetail = "Bilinmeyen sunucu hatası.";
        try {
          final decodedBody = jsonDecode(responseBody);
          if (decodedBody is Map && decodedBody.containsKey('detail')) {
            errorDetail = decodedBody['detail'];
          } else {
            errorDetail = responseBody;
          }
        } catch(_) {
          errorDetail = responseBody.isNotEmpty ? responseBody : "Kategoriler oluşturulamadı.";
        }
        throw Exception('Şablondan kategori oluşturulamadı: $errorDetail');
      }
    } catch (e) {
      debugPrint('createCategoriesFromTemplates sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Şablondan kategori oluşturulurken bir sorun oluştu.');
    }
  }

  static Future<List<dynamic>> fetchMenuItemsForBusiness(String token) async {
    final url = getUrl('/menu-items/');
    debugPrint("ApiService: Fetching menu items from $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Menü öğeleri alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('fetchMenuItemsForBusiness sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Menü öğeleri alınırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> createMenuItemForBusiness(
    String token,
    int businessId,
    String name,
    String description,
    int? categoryId,
    String? imageUrl,
    double? kdvRate,
  ) async {
    final url = getUrl('/menu-items/');
    final Map<String, dynamic> payload = {
      'business': businessId,
      'name': name,
      'description': description,
    };
    if (categoryId != null) {
      payload['category_id'] = categoryId;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      payload['image'] = imageUrl;
    }
    if (kdvRate != null) {
      payload['kdv_rate'] = kdvRate.toStringAsFixed(2);
    }

    debugPrint("ApiService: Creating menu item with payload: ${jsonEncode(payload)} via $url");
    try {
      final response = await _makeRequest('POST', url.toString(), body: payload);
      String responseBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 201) {
        return jsonDecode(responseBody);
      } else {
        debugPrint('createMenuItemForBusiness API hatası (${response.statusCode}): $responseBody');
        throw Exception(
            'Menü öğesi oluşturulamadı: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      debugPrint('createMenuItemForBusiness sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Menü öğesi oluşturulurken bir sorun oluştu.');
    }
  }

  static Future<void> deleteMenuItem(String token, int menuItemId) async {
    final url = getUrl('/menu-items/$menuItemId/');
    debugPrint("ApiService: Deleting menu item $menuItemId via $url");
    try {
      final response = await _makeRequest('DELETE', url.toString());
      if (response.statusCode != 204) {
        throw Exception('Menü öğesi silinemedi: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('deleteMenuItem sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Menü öğesi silinirken bir sorun oluştu.');
    }
  }

  // === YENİ METOT BAŞLANGICI: Menü Öğesi Şablonlarını Getir (GÜNCELLENDİ) ===
  static Future<List<dynamic>> fetchMenuItemTemplates(String token, {required String categoryTemplateName}) async {
    final url = getUrl('/templates/menu-item-templates/').replace(queryParameters: {
      'category_template_name': categoryTemplateName, // ID yerine NAME gönderiyoruz
    });
    debugPrint("ApiService: Fetching menu item templates for category name '$categoryTemplateName' from $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Ürün şablonları alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('fetchMenuItemTemplates sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Ürün şablonları alınırken bir sorun oluştu.');
    }
  }
  // === YENİ METOT SONU ===

  // === YENİ METOT BAŞLANGICI: Şablonlardan Menü Öğesi Oluştur ===
  static Future<List<dynamic>> createMenuItemsFromTemplates(
    String token, {
    required List<int> templateIds,
    required int targetCategoryId,
  }) async {
    final url = getUrl('/menu-items/create-from-template/');
    final payload = {
      'template_ids': templateIds,
      'target_category_id': targetCategoryId,
    };
    debugPrint("ApiService: Creating menu items from templates. Payload: ${jsonEncode(payload)}");
    try {
      final response = await _makeRequest('POST', url.toString(), body: payload);
      final String responseBody = utf8.decode(response.bodyBytes);
      if (response.statusCode == 201) {
        return jsonDecode(responseBody);
      } else {
        String errorDetail = "Bilinmeyen sunucu hatası.";
        try {
          final decodedBody = jsonDecode(responseBody);
          if (decodedBody is Map && decodedBody.containsKey('detail')) {
            errorDetail = decodedBody['detail'];
          } else {
            errorDetail = responseBody;
          }
        } catch (_) {
          errorDetail = responseBody.isNotEmpty ? responseBody : "Ürünler oluşturulamadı.";
        }
        throw Exception('Şablondan ürün oluşturulamadı: $errorDetail');
      }
    } catch (e) {
      debugPrint('createMenuItemsFromTemplates sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Şablondan ürün oluşturulurken bir sorun oluştu.');
    }
  }
  // === YENİ METOT SONU ===

  // === YENİ METOT BAŞLANGICI: Varyant Şablonları ===
  static Future<List<dynamic>> fetchVariantTemplates(String token, {String? categoryTemplateName}) async {
    try {
      String url = '$baseUrl/templates/variant-templates/';
      if (categoryTemplateName != null) {
        url += '?category_template_name=${Uri.encodeComponent(categoryTemplateName)}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept-Language': 'tr',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Varyant şablonları yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Varyant şablonları yüklenirken hata: $e');
    }
  }
  // === YENİ METOT SONU ===

  static Future<List<dynamic>> fetchVariantsForMenuItem(String token, int menuItemId) async {
    final url = getUrl('/menu-item-variants/').replace(queryParameters: {'menu_item': menuItemId.toString()});
    debugPrint("ApiService: Fetching variants for menu item $menuItemId from $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Varyantlar alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('fetchVariantsForMenuItem sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Varyantlar alınırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> createMenuItemVariant(
    String token,
    int menuItemId,
    String name,
    double price,
    bool isExtra,
    String? imageUrl,
  ) async {
    final url = getUrl('/menu-item-variants/');
    final Map<String, dynamic> payload = {
      'menu_item': menuItemId,
      'name': name,
      'price': price.toStringAsFixed(2),
      'is_extra': isExtra,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      payload['image'] = imageUrl;
    }

    debugPrint("ApiService: Creating menu item variant with payload: ${jsonEncode(payload)} via $url");
    try {
      final response = await _makeRequest('POST', url.toString(), body: payload);
      if (response.statusCode == 201) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('createMenuItemVariant API hatası (${response.statusCode}): $errorBody');
        String errorMessage = 'Varyant oluşturulamadı: ${response.statusCode}';
        try {
          Map<String, dynamic> errorData = jsonDecode(errorBody);
          if (errorData['name'] is List && errorData['name'].isNotEmpty) {
            errorMessage = 'Varyant Adı: ${errorData['name'][0]}';
          } else if (errorData['price'] is List && errorData['price'].isNotEmpty) {
            errorMessage = 'Fiyat: ${errorData['price'][0]}';
          } else if (errorData['detail'] is String) {
            errorMessage = errorData['detail'];
          } else {
            errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('createMenuItemVariant sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Varyant oluşturulurken bir sorun oluştu.');
    }
  }

  static Future<void> deleteMenuItemVariant(String token, int variantId) async {
    final url = getUrl('/menu-item-variants/$variantId/');
    debugPrint("ApiService: Deleting menu item variant $variantId via $url");
    try {
      final response = await _makeRequest('DELETE', url.toString());
      if (response.statusCode != 204) {
        throw Exception('Varyant silinemedi: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('deleteMenuItemVariant sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Varyant silinirken bir sorun oluştu.');
    }
  }

  static Future<List<dynamic>> fetchBusinessStock(String token) async {
    final url = getUrl('/stocks/');
    debugPrint("ApiService: Fetching business stock from $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception('Stok bilgileri alınamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('fetchBusinessStock sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Stok bilgileri alınırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> createOrUpdateStock(
    String token, {
    required int variantId,
    required int quantity,
    int? stockId,
  }) async {
    final Map<String, dynamic> payload = {
      'variant': variantId,
      'quantity': quantity,
    };
    http.Response response;
    String debugAction = "";

    try {
      if (stockId != null) {
        final url = getUrl('/stocks/$stockId/');
        debugAction = "Updating stock $stockId";
        debugPrint("ApiService: $debugAction with payload: ${jsonEncode(payload)} via PUT to $url");
        response = await _makeRequest('PUT', url.toString(), body: payload);
      } else {
        final url = getUrl('/stocks/');
        debugAction = "Creating stock";
        debugPrint("ApiService: $debugAction with payload: ${jsonEncode(payload)} via POST to $url");
        response = await _makeRequest('POST', url.toString(), body: payload);
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('$debugAction API hatası (${response.statusCode}): $errorBody');
        String errorMessage = 'Stok işlemi başarısız: ${response.statusCode}';
        try {
          Map<String, dynamic> errorData = jsonDecode(errorBody);
          if (errorData['variant'] is List && errorData['variant'].isNotEmpty) {
            errorMessage = 'Stok işlemi: ${errorData['variant'][0]}';
          } else if (errorData['quantity'] is List && errorData['quantity'].isNotEmpty) {
            errorMessage = 'Stok işlemi: ${errorData['quantity'][0]}';
          } else if (errorData['detail'] is String) {
            errorMessage = 'Stok işlemi: ${errorData['detail']}';
          } else {
            errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('$debugAction sırasında ağ/servis hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Stok işlemi sırasında bir hata oluştu.');
    }
  }

  static Future<void> requestPasswordReset(String email) async {
    final url = getUrl('/password-reset/request/');
    debugPrint("ApiService: Requesting password reset for email $email via $url");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        debugPrint("Password reset request successful (or email not found, but backend returned OK to prevent enumeration): ${utf8.decode(response.bodyBytes)}");
        return;
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('Request Password Reset API hatası (${response.statusCode}): $errorBody');
        String errorMessage = 'Şifre sıfırlama isteği başarısız: ${response.statusCode}';
        try {
          Map<String, dynamic> errorData = jsonDecode(errorBody);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          } else if (errorData.containsKey('email') && errorData['email'] is List && errorData['email'].isNotEmpty) {
            errorMessage = errorData['email'][0];
          } else {
            errorMessage = errorBody;
          }
        } catch (e) {
          errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Request Password Reset sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Şifre sıfırlama isteği gönderilirken bir sorun oluştu.');
    }
  }

  static Future<void> confirmPasswordResetWithCode(
    String email,
    String code,
    String newPassword1,
    String newPassword2,
  ) async {
    final url = getUrl('/password-reset/confirm-code/');
    debugPrint("ApiService: Confirming password reset for email $email with code $code via $url");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'new_password1': newPassword1,
          'new_password2': newPassword2,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint("Password reset confirmation successful: ${utf8.decode(response.bodyBytes)}");
        return;
      } else {
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('Confirm Password Reset API hatası (${response.statusCode}): $errorBody');
        String errorMessage = 'Şifre sıfırlama başarısız: ${response.statusCode}';
        try {
          Map<String, dynamic> errorData = jsonDecode(errorBody);
          if (errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          } else if (errorData.keys.isNotEmpty) {
            String firstErrorKey = errorData.keys.first;
            if (errorData[firstErrorKey] is List && errorData[firstErrorKey].isNotEmpty) {
              String friendlyKey = firstErrorKey.replaceAll('_', ' ').capitalize();
              errorMessage = '${friendlyKey}: ${errorData[firstErrorKey][0]}';
            } else if (errorData[firstErrorKey] is String) {
              String friendlyKey = firstErrorKey.replaceAll('_', ' ').capitalize();
              errorMessage = '${friendlyKey}: ${errorData[firstErrorKey]}';
            } else {
              errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
            }
          } else {
            errorMessage = errorBody.isNotEmpty ? errorBody : 'Bilinmeyen bir hata oluştu.';
          }
        } catch (jsonErr) {
          errorMessage = errorBody.isNotEmpty ? errorBody : 'Sunucudan anlaşılmayan bir yanıt alındı.';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Confirm Password Reset sırasında ağ hatası: $e');
      if (e is Exception) throw e;
      throw Exception('Şifre sıfırlama onaylanırken bir sorun oluştu.');
    }
  }

  static Future<Map<String, dynamic>> fetchCurrentShift(String token) async {
    final url = getUrl('/staff-users/current-shift/');
    debugPrint("ApiService: Fetching current shift from $url");
    try {
      final response = await _makeRequest('GET', url.toString());
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode == 404) {
        throw Exception('Aktif vardiya bulunamadı.');
      } else {
        throw Exception('Vardiya bilgisi alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Vardiya bilgisi alınırken bir sorun oluştu: $e');
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
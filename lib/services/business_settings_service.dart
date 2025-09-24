// lib/services/business_settings_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class BusinessSettingsService {
  static Future<Map<String, dynamic>> fetchPaymentSettings(String token, int businessId) async {
    final response = await http.get(
      ApiService.getUrl('/businesses/$businessId/payment-settings/'),
      headers: ApiService.getHeaders(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Ödeme ayarları alınamadı: ${response.statusCode}');
    }
  }

  static Future<void> updatePaymentSettings({
    required String token,
    required int businessId,
    required String provider,
    String? apiKey,
    String? secretKey,
  }) async {
    final Map<String, dynamic> payload = {
      'payment_provider': provider,
    };
    
    // DÜZELTME: Sadece dolu değerler varsa payload'a ekle
    if (apiKey != null && apiKey.isNotEmpty) {
      payload['payment_api_key'] = apiKey;
    }
    
    if (secretKey != null && secretKey.isNotEmpty) {
      payload['payment_secret_key'] = secretKey;
    }

    final response = await http.put(
      ApiService.getUrl('/businesses/$businessId/payment-settings/'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(errorBody['detail'] ?? 'Ayarlar güncellenirken bir hata oluştu.');
    }
  }
}
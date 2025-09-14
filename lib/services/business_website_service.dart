// lib/services/business_website_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/business_website.dart';

class BusinessWebsiteService {
  /// İşletme sahibinin web sitesi ayarlarını getirir.
  static Future<BusinessWebsite> fetchWebsiteSettings(String token) async {
    final url = ApiService.getUrl('/business/website/');
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return BusinessWebsite.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('Web sitesi ayarları alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Web sitesi ayarları çekilirken bir hata oluştu: $e');
    }
  }

  /// İşletme sahibinin web sitesi ayarlarını günceller.
  static Future<void> updateWebsiteSettings(String token, Map<String, dynamic> payload) async {
    final url = ApiService.getUrl('/business/website/');
    try {
      final response = await http.patch( // Kısmi güncelleme için PATCH kullanmak daha iyidir
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Web sitesi ayarları güncellenemedi: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      throw Exception('Web sitesi ayarları güncellenirken bir hata oluştu: $e');
    }
  }
}
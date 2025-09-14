// lib/services/website_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/business_website.dart';
import 'api_service.dart';

class WebsiteService {
  /// İşletmenin web sitesi detaylarını backend'den çeker.
  static Future<BusinessWebsite> fetchWebsiteDetails(String token) async {
    final response = await http.get(
      ApiService.getUrl('/business/website/'),
      headers: ApiService.getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return BusinessWebsite.fromJson(data);
    } else {
      throw Exception('Failed to load website details: ${response.statusCode}');
    }
  }

  /// İşletmenin web sitesi ayarlarını günceller.
  static Future<void> updateWebsiteDetails(String token, Map<String, dynamic> data) async {
    final response = await http.patch( // Kısmi güncelleme için PATCH kullanmak daha iyidir
      ApiService.getUrl('/business/website/'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update website details: ${utf8.decode(response.bodyBytes)}');
    }
  }
}
// lib/services/layout_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http; // DOĞRU IMPORT
import '../models/business_layout.dart';
import '../models/table_model.dart';
import '../models/layout_element.dart';
import 'api_service.dart';
import 'dart:convert' show utf8;

class LayoutService {
  static Future<BusinessLayout> fetchLayout(String token) async {
    final response = await http.get(
      ApiService.getUrl('/layouts/'),
      headers: ApiService.getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return BusinessLayout.fromJson(data);
    } else {
      throw Exception('Failed to load layout data: ${response.body}');
    }
  }

  static Future<void> bulkUpdateTablePositions(String token, List<TableModel> tables) async {
    // Önce minimal JSON formatını oluştur
    final List<Map<String, dynamic>> payload = tables.map((t) => t.toJsonForUpdate()).toList();

    // DEBUG: gönderilen payload'u logla (console / devtools)
    developer.log('DEBUG bulkUpdateTablePositions payload: ${jsonEncode(payload)}', name: 'LayoutService');

    // Basit doğrulama: tüm öğelerde id olmalı
    final List<dynamic> missingIdEntries = [];
    for (var item in payload) {
      if (item['id'] == null) {
        missingIdEntries.add(item);
      }
    }
    if (missingIdEntries.isNotEmpty) {
      // Geliştiriciye açık, kullanıcıya gösterilebilecek bir hata at.
      throw Exception('bulkUpdateTablePositions: Gönderilen payload içinde id eksik olan tablolar var. Örnek: ${jsonEncode(missingIdEntries.take(3).toList())}');
    }

    final response = await http.post(
      ApiService.getUrl('/tables/bulk-update-positions/'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode(payload),
    );

    // DEBUG: response status ve body
    developer.log('DEBUG bulkUpdateTablePositions status: ${response.statusCode}', name: 'LayoutService');
    developer.log('DEBUG bulkUpdateTablePositions body: ${response.body}', name: 'LayoutService');

    if (response.statusCode != 200) {
      throw Exception('Failed to update table positions: ${response.body}');
    }
  }

  // ... bulkUpdateLayoutElements aynı kaldı ...
  static Future<List<LayoutElement>> bulkUpdateLayoutElements(String token, List<LayoutElement> elements) async {
    final List<Map<String, dynamic>> payload = elements.map((e) => e.toJson()).toList();
    
    final response = await http.post(
      ApiService.getUrl('/layout-elements/bulk-update/'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      if (response.bodyBytes.isNotEmpty) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return data.map<LayoutElement>((item) => LayoutElement.fromJson(Map<String, dynamic>.from(item))).toList();
        }
      }
      return elements;
    } else {
      throw Exception('Failed to update layout elements: ${response.body}');
    }
  }
}
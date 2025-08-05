// lib/services/kds_management_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/kds_screen_model.dart';

class KdsManagementService {
  /// İşletmeye ait tüm KDS ekranlarını getirir.
  static Future<List<KdsScreenModel>> fetchKdsScreens(String token, int businessId) async {
    final url = ApiService.getUrl('/kds-screens/');
    debugPrint("KdsManagementService: Fetching KDS Screens from $url");
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => KdsScreenModel.fromJson(json)).toList();
      } else {
        debugPrint('Fetch KDS Screens API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('KDS ekranları alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Fetch KDS Screens Network Error: $e');
      if (e is Exception && e.toString().contains('SocketException')) {
        throw Exception('KDS ekranları çekilirken ağ bağlantı hatası oluştu. Lütfen internet bağlantınızı kontrol edin.');
      }
      throw Exception('KDS ekranları çekilirken bir sorun oluştu: $e');
    }
  }

  /// Yeni bir KDS ekranı oluşturur.
  static Future<KdsScreenModel> createKdsScreen(
    String token,
    int businessId,
    String name,
    String? description,
    bool isActive,
  ) async {
    final url = ApiService.getUrl('/kds-screens/');
    final Map<String, dynamic> payload = {
      'business': businessId,
      'name': name,
      'is_active': isActive,
      'description': description ?? "",
    };

    debugPrint("KdsManagementService: Creating KDS Screen with payload: ${jsonEncode(payload)}");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        return KdsScreenModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        String errorDetail = "Bilinmeyen sunucu hatası.";
        try {
            final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
            if (decodedBody is Map && decodedBody.containsKey('business')) {
                errorDetail = "İşletme: ${decodedBody['business'][0]}";
            } else if (decodedBody is Map && decodedBody['name'] is List && decodedBody['name'].isNotEmpty) {
                errorDetail = decodedBody['name'][0];
            } else if (decodedBody is Map && decodedBody.containsKey('detail')) {
                errorDetail = decodedBody['detail'];
            } else {
                errorDetail = utf8.decode(response.bodyBytes);
            }
        } catch(_) {
            errorDetail = utf8.decode(response.bodyBytes).isNotEmpty ? utf8.decode(response.bodyBytes) : "KDS ekranı oluşturulamadı.";
        }
        debugPrint('Create KDS Screen API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('KDS ekranı oluşturulamadı: $errorDetail');
      }
    } catch (e) {
      debugPrint('Create KDS Screen Network Error: $e');
      if (e is Exception) throw e;
      throw Exception('KDS ekranı oluşturulurken bir sorun oluştu.');
    }
  }

  /// Mevcut bir KDS ekranını günceller.
  static Future<KdsScreenModel> updateKdsScreen(
    String token,
    int kdsScreenId,
    int businessId, // YENİ: businessId parametresi eklendi
    String name,
    String? description,
    bool isActive,
  ) async {
    final url = ApiService.getUrl('/kds-screens/$kdsScreenId/');
    final Map<String, dynamic> payload = {
      'name': name,
      'is_active': isActive,
      'business': businessId, // YENİ: Payload'a businessId eklendi
      'description': description ?? "",
    };

    debugPrint("KdsManagementService: Updating KDS Screen $kdsScreenId with payload: ${jsonEncode(payload)}");
    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return KdsScreenModel.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
          String errorDetail = "Bilinmeyen sunucu hatası.";
        try {
            final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
            if (decodedBody is Map && decodedBody.containsKey('business')) {
                errorDetail = "İşletme: ${decodedBody['business'][0]}";
            } else if (decodedBody is Map && decodedBody.containsKey('detail')) {
                errorDetail = decodedBody['detail'];
            } else if (decodedBody is Map && decodedBody['name'] is List && decodedBody['name'].isNotEmpty) {
                errorDetail = decodedBody['name'][0];
            } else {
                errorDetail = utf8.decode(response.bodyBytes);
            }
        } catch(_) {
            errorDetail = utf8.decode(response.bodyBytes).isNotEmpty ? utf8.decode(response.bodyBytes) : "KDS ekranı güncellenemedi.";
        }
        debugPrint('Update KDS Screen API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('KDS ekranı güncellenemedi: $errorDetail');
      }
    } catch (e) {
      debugPrint('Update KDS Screen Network Error: $e');
      if (e is Exception) throw e;
      throw Exception('KDS ekranı güncellenirken bir sorun oluştu.');
    }
  }

  /// Bir KDS ekranını sistemden siler.
  static Future<void> deleteKdsScreen(String token, int kdsScreenId) async {
    final url = ApiService.getUrl('/kds-screens/$kdsScreenId/');
    debugPrint("KdsManagementService: Deleting KDS Screen $kdsScreenId");
    try {
      final response = await http.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode != 204) {
        debugPrint('Delete KDS Screen API Error (${response.statusCode}): ${response.body.isNotEmpty ? utf8.decode(response.bodyBytes) : "No content"}');
        throw Exception('KDS ekranı silinemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Delete KDS Screen Network Error: $e');
      if (e is Exception) throw e;
      throw Exception('KDS ekranı silinirken bir sorun oluştu.');
    }
  }
}
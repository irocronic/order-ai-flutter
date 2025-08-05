// lib/services/kds_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/kds_screen_model.dart';

class KdsService {
  /// Birden çok KDS ekranını tek bir istekte oluşturur.
  /// Backend artık bir nesne listesi bekliyor: [{"name": "Mutfak", "business": 1}, {"name": "Bar", "business": 1}]
  // ==================== METOT GÜNCELLENDİ ====================
  static Future<List<KdsScreenModel>> bulkCreateKdsScreens(String token, int businessId, List<String> names) async {
    final url = ApiService.getUrl('/kds-screens/');
    
    // DEĞİŞİKLİK: Payload'a 'business' alanı eklendi ve Map tipi <String, dynamic> olarak güncellendi.
    final List<Map<String, dynamic>> payload = names.map((name) => {
      'name': name,
      'business': businessId, // <<< EKSİK OLAN SATIR BUYDU
    }).toList();
    
    debugPrint("KdsService: Bulk creating KDS screens with payload: ${jsonEncode(payload)}");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => KdsScreenModel.fromJson(json)).toList();
      } else {
        // Hata mesajı JSON içerdiği için doğrudan fırlatılabilir.
        // UI tarafındaki catch bloğu bu hatayı doğru şekilde işleyecektir.
        String errorBody = utf8.decode(response.bodyBytes);
        debugPrint('Bulk Create KDS Screens API Error (${response.statusCode}): $errorBody');
        throw Exception(
            'KDS ekranları oluşturulamadı: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      debugPrint('Bulk Create KDS Screens Network Error: $e');
      if (e is Exception) throw e;
      throw Exception('KDS ekranları oluşturulurken bir ağ hatası oluştu.');
    }
  }
  // ==================== GÜNCELLEME SONU ====================

  /// İşletmeye ait tüm KDS ekranlarını getirir.
  static Future<List<KdsScreenModel>> fetchKdsScreens(String token, int businessId) async {
    final url = ApiService.getUrl('/kds-screens/');
    debugPrint("KdsService: Fetching KDS Screens from $url");
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

    debugPrint("KdsService: Creating KDS Screen with payload: ${jsonEncode(payload)}");
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
    int businessId,
    String name,
    String? description,
    bool isActive,
  ) async {
    final url = ApiService.getUrl('/kds-screens/$kdsScreenId/');
    final Map<String, dynamic> payload = {
      'name': name,
      'is_active': isActive,
      'business': businessId,
      'description': description ?? "",
    };

    debugPrint("KdsService: Updating KDS Screen $kdsScreenId with payload: ${jsonEncode(payload)}");
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
    debugPrint("KdsService: Deleting KDS Screen $kdsScreenId");
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

  /// Belirli bir KDS Ekranı için aktif siparişleri çeker.
  static Future<List<dynamic>> fetchKDSOrders(String token, String kdsScreenSlug) async {
    if (kdsScreenSlug.isEmpty) {
      debugPrint("KdsService: fetchKDSOrders - kdsScreenSlug boş olduğu için istek yapılmadı.");
      return [];
    }
    final url = ApiService.getUrl('/kds-orders/$kdsScreenSlug/');
    debugPrint("KdsService: Fetching KDS Orders for slug '$kdsScreenSlug' from $url");
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('KDS Orders API Error (${response.statusCode}) for slug $kdsScreenSlug: ${utf8.decode(response.bodyBytes)}');
        return [];
      }
    } catch (e) {
      debugPrint('KDS Orders Network Error ($kdsScreenSlug): $e');
      return [];
    }
  }

  /// Belirli bir KDS Ekranı için aktif sipariş sayısını çeker.
  static Future<int> fetchActiveKdsOrderCount(String token, String kdsScreenSlug) async {
    if (kdsScreenSlug.isEmpty) {
      debugPrint("KdsService: fetchActiveKdsOrderCount - kdsScreenSlug boş, sayaç 0 olarak ayarlandı.");
      return 0;
    }
    try {
      final orders = await fetchKDSOrders(token, kdsScreenSlug);
      return orders.length;
    } catch (e) {
      debugPrint("fetchActiveKdsOrderCount error for slug $kdsScreenSlug: $e");
      return 0;
    }
  }

  /// Bir siparişin tamamını "Hazırlanıyor" durumuna alır.
  static Future<http.Response> startPreparation(String token, String kdsScreenSlug, int orderId) async {
    if (kdsScreenSlug.isEmpty) {
      debugPrint("KdsService: startPreparation - kdsScreenSlug boş.");
      throw Exception('KDS ekran bilgisi eksik.');
    }
    final url = ApiService.getUrl('/kds-orders/$kdsScreenSlug/$orderId/start-preparation/');
    debugPrint("KdsService: Starting preparation for order $orderId on KDS '$kdsScreenSlug' via $url");
    try {
      final response = await http.post(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        debugPrint('KDS Start Preparation API Error (${response.statusCode}) for order $orderId on KDS $kdsScreenSlug: ${utf8.decode(response.bodyBytes)}');
        throw Exception('Sipariş hazırlamaya başlama işlemi başarısız: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('KDS Start Preparation Network Error for order $orderId on KDS $kdsScreenSlug: $e');
      if (e is Exception) throw e;
      throw Exception('Sipariş hazırlamaya başlama hatası: $e');
    }
  }

  /// Bir siparişin tamamını "Mutfakta Hazır" durumuna alır.
  static Future<http.Response> markOrderReady(String token, String kdsScreenSlug, int orderId) async {
    if (kdsScreenSlug.isEmpty) {
      debugPrint("KdsService: markOrderReady - kdsScreenSlug boş.");
      throw Exception('KDS ekran bilgisi eksik.');
    }
    final url = ApiService.getUrl('/kds-orders/$kdsScreenSlug/$orderId/mark-ready-for-pickup/');
    debugPrint("KdsService: Marking order $orderId ready on KDS '$kdsScreenSlug' via $url");
    try {
      final response = await http.post(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        debugPrint('KDS Mark Ready API Error (${response.statusCode}) for order $orderId on KDS $kdsScreenSlug: ${utf8.decode(response.bodyBytes)}');
        throw Exception('Sipariş hazır olarak işaretlenemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('KDS Mark Ready Network Error for order $orderId on KDS $kdsScreenSlug: $e');
      if (e is Exception) throw e;
      throw Exception('Sipariş hazır işaretleme hatası: $e');
    }
  }

  /// Tek bir sipariş kalemini "Hazırlanıyor" olarak işaretler.
  static Future<http.Response> startPreparingItem(String token, int orderItemId) async {
    final url = ApiService.getUrl('/order_items/$orderItemId/start-preparing/');
    debugPrint("KdsService: Starting preparation for OrderItem ID: $orderItemId");
    try {
      final response = await http.post(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        throw Exception('Ürün hazırlama işlemi başarısız: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) throw e;
      throw Exception('Ürün hazırlama hatası: $e');
    }
  }

  /// Tek bir sipariş kalemini "Hazır" olarak işaretler.
  static Future<http.Response> markItemReady(String token, int orderItemId) async {
    final url = ApiService.getUrl('/order_items/$orderItemId/mark-ready/');
    debugPrint("KdsService: Marking OrderItem ID: $orderItemId as ready");
    try {
      final response = await http.post(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return response;
      } else {
        throw Exception('Ürün hazır olarak işaretlenemedi: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) throw e;
      throw Exception('Ürün hazır işaretleme hatası: $e');
    }
  }
}
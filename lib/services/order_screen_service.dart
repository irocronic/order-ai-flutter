// lib/services/order_screen_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/menu_item.dart';
import 'api_service.dart';
import 'connectivity_service.dart';
import 'cache_service.dart';
import 'order_service.dart';

/// CreateOrderScreen için özel API çağrılarını ve veri işleme mantığını yönetir.
class OrderScreenService {
  /// Çevrimdışı ve çevrimiçi modları destekleyen merkezi veri çekme fonksiyonu.
  static Future<Map<String, dynamic>> fetchInitialData(String token, int businessId) async {
    if (ConnectivityService.instance.isOnlineNotifier.value) {
      return _fetchDataFromApi(token, businessId);
    } else {
      return _fetchDataFromCache();
    }
  }

  /// Çevrimiçiyken API'den tüm verileri çeker ve önbelleğe alır.
  static Future<Map<String, dynamic>> _fetchDataFromApi(String token, int businessId) async {
    debugPrint("[OrderScreenService] (Online) Başlangıç verileri API'den çekiliyor...");
    String overallErrorMessage = '';

    try {
      final results = await Future.wait([
        _fetchAndCacheTables(token).catchError((e) {
          debugPrint("Hata (_fetchAndCacheTables): $e");
          overallErrorMessage += "Masa verileri alınamadı. ";
          return null;
        }),
        OrderService.fetchCategories(token).catchError((e) {
          debugPrint("Hata (fetchCategories): $e");
          overallErrorMessage += "Kategori verileri alınamadı. ";
          return null;
        }),
        OrderService.fetchMenuItems(token).catchError((e) {
          debugPrint("Hata (fetchMenuItems): $e");
          overallErrorMessage += "Menü verileri alınamadı. ";
          return null;
        }),
        OrderService.fetchPendingOrdersOnly(token, businessId).catchError((e) {
          debugPrint("Hata (fetchPendingOrdersOnly): $e");
          return <dynamic>[];
        }),
        OrderService.fetchWaitingCountOnly(token).catchError((e) {
          debugPrint("Hata (fetchWaitingCountOnly): $e");
          return 0;
        }),
      ]);

      final tables = results[0] as List<dynamic>? ?? [];
      final menuItemsData = results[2] as List<dynamic>? ?? [];
      final menuItems = menuItemsData.map((e) => MenuItem.fromJson(e)).toList();
      final pendingOrders = results[3] as List<dynamic>? ?? [];
      final waitingCount = results[4] as int? ?? 0;

      return {
        'tables': tables,
        'pendingOrders': pendingOrders,
        'menuItems': menuItems,
        'waitingCount': waitingCount,
        'errorMessage': overallErrorMessage.trim().isNotEmpty ? overallErrorMessage.trim() : null,
        'success': overallErrorMessage.trim().isEmpty,
      };
    } catch (e) {
      overallErrorMessage = "Veriler alınırken genel bir hata oluştu: $e";
      return {
        'tables': [], 'pendingOrders': [], 'menuItems': [], 'waitingCount': 0,
        'errorMessage': overallErrorMessage, 'success': false,
      };
    }
  }

  /// Çevrimdışıyken tüm verileri önbellekten okur.
  static Future<Map<String, dynamic>> _fetchDataFromCache() async {
    debugPrint("[OrderScreenService] (Offline) Başlangıç verileri önbellekten okunuyor...");
    try {
      final tables = CacheService.instance.getCachedData('tables');
      final menuItemsData = CacheService.instance.getCachedData('menu_items');
      final categories = CacheService.instance.getCachedData('categories');

      if (tables == null || menuItemsData == null || categories == null) {
        throw Exception("Çevrimdışı modda çalışabilmek için lütfen en az bir kez internete bağlanın.");
      }

      final temporaryPendingOrders = CacheService.instance.getTemporaryOrders();
      debugPrint("[OrderScreenService] (Offline) Önbellekten ${temporaryPendingOrders.length} adet geçici sipariş okundu.");

      return {
        'tables': tables,
        'pendingOrders': temporaryPendingOrders,
        'menuItems': menuItemsData.map((e) => MenuItem.fromJson(e)).toList(),
        'waitingCount': 0,
        'errorMessage': null,
        'success': true,
      };
    } catch (e) {
      return {
        'tables': [], 'pendingOrders': [], 'menuItems': [], 'waitingCount': 0,
        'errorMessage': e.toString().replaceFirst("Exception: ", ""), 'success': false,
      };
    }
  }
  
  /// Sadece masaları çekip önbelleğe alan yardımcı fonksiyon.
  static Future<List<dynamic>> _fetchAndCacheTables(String token) async {
    final url = ApiService.getUrl('/tables/');
    final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      await CacheService.instance.cacheData('tables', data);
      debugPrint("[OrderScreenService] (Online) Masa verileri başarıyla çekildi ve önbelleğe alındı.");
      return data;
    } else {
      throw Exception("Masalar alınamadı (${response.statusCode})");
    }
  }

  /// Masa transferi API isteğini gönderir.
  static Future<http.Response> transferOrder(String token, int orderId, int newTableId) async {
    final url = ApiService.getUrl('/orders/transfer/');
    return await http.post(
      url,
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode({
        "order": orderId,
        "new_table": newTableId,
      }),
    );
  }

  /// Siparişi iptal etme API isteğini gönderir.
  static Future<http.Response> cancelOrder(String token, int orderId) async {
    final url = ApiService.getUrl('/orders/$orderId/');
    return await http.delete(
      url,
      headers: {"Authorization": "Bearer $token"},
    );
  }
}
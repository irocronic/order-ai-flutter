// lib/services/stock_service.dart (Güncellenmiş Versiyon)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/stock.dart';
import '../models/stock_movement.dart';
import '../utils/notifiers.dart'; // <<< YENİ: Notifier'ları import ediyoruz

class StockService {
    /// İşletmeye ait tüm stokları getirir.
    static Future<List<Stock>> fetchBusinessStock(String token) async {
        final url = ApiService.getUrl('/stocks/');
        debugPrint("StockService: Fetching business stock from $url");
        try {
            final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
            if (response.statusCode == 200) {
                List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
                return data.map((json) => Stock.fromJson(json)).toList();
            } else {
                throw Exception('Stok bilgileri alınamadı: ${response.statusCode}');
            }
        } catch (e) {
            throw Exception('Stok bilgileri çekilirken hata: $e');
        }
    }

    // <<< YENİ METOT BAŞLANGICI >>>
    /// Tüm stokları kontrol eder ve genel bir uyarı durumu olup olmadığını belirleyerek
    /// ilgili notifier'ı günceller.
    static Future<void> checkAndNotifyGlobalStockAlerts(String token) async {
        debugPrint("[StockService] Genel stok uyarı durumu kontrol ediliyor...");
        try {
            final stocks = await fetchBusinessStock(token);
            bool alertFound = false;
            for (final stock in stocks) {
                if (stock.trackStock && stock.alertThreshold != null && stock.quantity <= stock.alertThreshold!) {
                    alertFound = true;
                    break; // Bir tane uyarı bulmak yeterli
                }
            }
            // Notifier'ı yeni durumla güncelle
            stockAlertNotifier.value = alertFound;
            debugPrint("[StockService] Genel stok uyarı durumu güncellendi: $alertFound");
        } catch (e) {
            debugPrint("Genel stok uyarı durumu kontrol edilirken hata: $e");
            // Hata durumunda uyarıyı false yapabiliriz ki yanlış bir ikon gösterilmesin.
            stockAlertNotifier.value = false;
        }
    }
    // <<< YENİ METOT SONU >>>


    /// Stok ayarlarını (takip durumu, uyarı eşiği) günceller.
    static Future<http.Response> updateStockSettings({
        required String token,
        required int stockId,
        required bool trackStock,
        int? alertThreshold,
    }) async {
        final url = ApiService.getUrl('/stocks/$stockId/');
        final Map<String, dynamic> payload = {
            'track_stock': trackStock,
            'alert_threshold': alertThreshold,
        };
        return http.patch(
            url,
            headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $token",
            },
            body: jsonEncode(payload),
        );
    }

    /// Belirli bir stok için stok hareketlerini çeker.
    static Future<List<StockMovement>> fetchStockMovements({
        required String token,
        int? stockId,
        int? variantId,
        String? movementType,
        DateTime? startDate,
        DateTime? endDate,
    }) async {
        Uri url;
        Map<String, String> queryParams = {};

        if (stockId != null) {
            url = ApiService.getUrl('/stocks/$stockId/history/');
        } else if (variantId != null) {
            url = ApiService.getUrl('/stock-movements/');
            queryParams['variant_id'] = variantId.toString();
        } else {
            url = ApiService.getUrl('/stock-movements/');
        }

        if (movementType != null && movementType.isNotEmpty) {
            queryParams['movement_type'] = movementType;
        }
        if (startDate != null) {
            queryParams['start_date'] = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
        }
        if (endDate != null) {
            queryParams['end_date'] = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
        }

        if (queryParams.isNotEmpty) {
            url = url.replace(queryParameters: queryParams);
        }

        try {
            final response = await http.get(
                url,
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": "Bearer $token",
                },
            );

            if (response.statusCode == 200) {
                List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
                return data.map((json) => StockMovement.fromJson(json)).toList();
            } else {
                throw Exception('Stok hareketleri alınamadı: ${response.statusCode} - ${response.body}');
            }
        } catch (e) {
            throw Exception('Stok hareketleri çekilirken hata: $e');
        }
    }

    /// Yeni bir stok ayarlama/düzeltme hareketi gönderir.
    static Future<http.Response> adjustStock({
        required String token,
        required int stockId,
        required String movementType,
        required int quantityChange,
        String? description,
    }) async {
        final url = ApiService.getUrl('/stocks/$stockId/adjust-stock/');
        return await http.post(
            url,
            headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $token",
            },
            body: jsonEncode({
                'movement_type': movementType,
                'quantity_change': quantityChange,
                if (description != null && description.isNotEmpty) 'description': description,
            }),
        );
    }

    /// Yeni bir stok kaydı oluşturur.
    static Future<http.Response> createStock({
        required String token,
        required int variantId,
        required int quantity,
    }) async {
        final url = ApiService.getUrl('/stocks/');
        return await http.post(
            url,
            headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $token",
            },
            body: jsonEncode({
                'variant': variantId,
                'quantity': quantity,
            }),
        );
    }
}
// lib/services/reservation_service.dart (YENİ DOSYA)

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reservation.dart';
import 'api_service.dart';

class ReservationService {
  /// İşletmeye ait rezervasyonları getirir.
  static Future<List<Reservation>> fetchReservations(String token, {String? status, int? tableId}) async {
    Map<String, String> queryParams = {};
    if (status != null) queryParams['status'] = status;
    if (tableId != null) queryParams['table_id'] = tableId.toString();

    final url = ApiService.getUrl('/reservations/').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await http.get(url, headers: {"Authorization": "Bearer $token"});

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Reservation.fromJson(json)).toList();
    } else {
      throw Exception('Rezervasyonlar alınamadı: ${response.statusCode}');
    }
  }

  /// Bir rezervasyonu onaylar.
  static Future<void> confirmReservation(String token, int reservationId) async {
    final url = ApiService.getUrl('/reservations/$reservationId/confirm/');
    final response = await http.post(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode != 200) {
      throw Exception('Rezervasyon onaylanamadı: ${response.statusCode}');
    }
  }

  /// Bir rezervasyonu iptal eder.
  static Future<void> cancelReservation(String token, int reservationId) async {
    final url = ApiService.getUrl('/reservations/$reservationId/cancel/');
    final response = await http.post(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode != 200) {
      throw Exception('Rezervasyon iptal edilemedi: ${response.statusCode}');
    }
  }
}
// lib/services/schedule_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // TimeOfDay ve Color için gerekli
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api_service.dart';
import '../models/shift_model.dart';
import '../models/scheduled_shift_model.dart';
import '../services/user_session.dart';

class ScheduleService {
  /// Belirtilen personellere, belirtilen tarihler için tek bir vardiya şablonunu atar.
  static Future<http.Response> assignShiftToMultiple({
    required String token,
    required List<int> staffIds,
    required List<DateTime> dates,
    required int shiftId,
  }) async {
    // Django'da bu isteği karşılayacak özel bir action olmalı. Örn: /schedule/bulk_create/
    final url = ApiService.getUrl('/schedule/bulk_create/');

    final List<String> formattedDates =
        dates.map((date) => DateFormat('yyyy-MM-dd').format(date)).toList();

    final Map<String, dynamic> payload = {
      'staff_ids': staffIds,
      'dates': formattedDates,
      'shift_id': shiftId,
    };

    debugPrint(
        "ScheduleService: Assigning shift to multiple staff/days. Payload: ${jsonEncode(payload)}");

    return await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(payload),
    );
  }

  /// Yeni bir vardiya şablonu oluşturur.
  static Future<Shift> createShift(String token,
      {required String name,
      required TimeOfDay startTime,
      required TimeOfDay endTime,
      required Color color}) async {
    final url = ApiService.getUrl('/shifts/');
    String formattedStartTime =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    String formattedEndTime =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    // Renk kodunu #RRGGBB formatına çevir
    String hexColor = '#${color.value.toRadixString(16).substring(2)}';

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          'name': name,
          'start_time': formattedStartTime,
          'end_time': formattedEndTime,
          'color': hexColor,
        }),
      );
      if (response.statusCode == 201) {
        return Shift.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception(
            'Vardiya şablonu oluşturulamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('createShift Error: $e');
      throw Exception('Vardiya şablonu oluşturulurken hata: $e');
    }
  }

  /// Mevcut bir vardiya şablonunu günceller.
  static Future<Shift> updateShift(String token, int shiftId,
      {required String name,
      required TimeOfDay startTime,
      required TimeOfDay endTime,
      required Color color}) async {
    final url = ApiService.getUrl('/shifts/$shiftId/');
    String formattedStartTime =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    String formattedEndTime =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    String hexColor = '#${color.value.toRadixString(16).substring(2)}';

    try {
      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          'name': name,
          'start_time': formattedStartTime,
          'end_time': formattedEndTime,
          'color': hexColor,
        }),
      );
      if (response.statusCode == 200) {
        return Shift.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception(
            'Vardiya şablonu güncellenemedi: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('updateShift Error: $e');
      throw Exception('Vardiya şablonu güncellenirken hata: $e');
    }
  }

  /// Bir vardiya şablonunu siler.
  static Future<void> deleteShift(String token, int shiftId) async {
    final url = ApiService.getUrl('/shifts/$shiftId/');
    try {
      final response =
          await http.delete(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode != 204) {
        throw Exception('Vardiya şablonu silinemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('deleteShift Error: $e');
      throw Exception('Vardiya şablonu silinirken hata: $e');
    }
  }

  /// Tüm vardiya şablonlarını getirir.
  static Future<List<Shift>> fetchShifts(String token) async {
    final url = ApiService.getUrl('/shifts/');
    try {
      final response =
          await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => Shift.fromJson(json)).toList();
      } else {
        throw Exception(
            'Vardiya şablonları alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('fetchShifts Error: $e');
      throw Exception('Vardiya şablonları çekilirken hata: $e');
    }
  }

  /// Belirtilen tarih aralığındaki planlanmış vardiyaları getirir.
  static Future<List<ScheduledShift>> fetchScheduledShifts(
      String token, DateTime startDate, DateTime endDate) async {
    final url = ApiService.getUrl('/schedule/').replace(queryParameters: {
      'start_date': DateFormat('yyyy-MM-dd').format(startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(endDate),
    });
    try {
      final response =
          await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => ScheduledShift.fromJson(json)).toList();
      } else {
        throw Exception(
            'Planlanmış vardiyalar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('fetchScheduledShifts Error: $e');
      throw Exception('Planlanmış vardiyalar çekilirken hata: $e');
    }
  }

  /// Bir personele belirli bir tarih için vardiya atar.
  static Future<ScheduledShift> assignShiftToStaff(String token,
      {required int staffId,
      required int shiftId,
      required DateTime date}) async {
    final url = ApiService.getUrl('/schedule/');
    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          'staff': staffId,
          'shift': shiftId,
          'date': DateFormat('yyyy-MM-dd').format(date),
        }),
      );
      if (response.statusCode == 201) {
        return ScheduledShift.fromJson(
            jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception(
            'Vardiya atanamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('assignShiftToStaff Error: $e');
      throw Exception('Vardiya atanırken hata: $e');
    }
  }

  /// Atanmış bir vardiyayı siler.
  static Future<void> deleteScheduledShift(
      String token, int scheduledShiftId) async {
    final url = ApiService.getUrl('/schedule/$scheduledShiftId/');
    try {
      final response =
          await http.delete(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode != 204) {
        throw Exception('Atanmış vardiya silinemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('deleteScheduledShift Error: $e');
      throw Exception('Atanmış vardiya silinirken hata: $e');
    }
  }

  /// Bir personelin vardiyası olup olmadığını kontrol eder.
  static Future<bool> hasScheduledShifts(String token, int staffId) async {
    // DİKKAT: URL, metodun yeni konumu olan StaffUserViewSet'e göre güncellendi.
    final url = ApiService.getUrl('/staff-users/$staffId/has-shifts/');
    try {
      final response =
          await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['has_shifts'] as bool? ?? false;
      }
      return false; // Hata durumunda vardiyası yok varsayalım.
    } catch (e) {
      debugPrint('hasScheduledShifts Error: $e');
      return false;
    }
  }
}
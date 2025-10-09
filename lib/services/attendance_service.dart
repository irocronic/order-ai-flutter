// lib/services/attendance_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/attendance_record.dart';
import '../models/check_in_location.dart';
import 'api_service.dart';
import 'location_service.dart';

class AttendanceService {
  static Future<List<CheckInLocation>> fetchCheckInLocations(String token) async {
    try {
      final url = ApiService.getUrl('/attendance/locations/');
      final response = await http.get(
        url,
        headers: ApiService.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => CheckInLocation.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('fetch_locations_failed');
      }
    } catch (e) {
      debugPrint('fetchCheckInLocations error: $e');
      throw Exception('fetch_locations_error');
    }
  }

  static Future<CheckInLocation> createCheckInLocation(
    String token, {
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    bool isActive = true,
  }) async {
    try {
      final url = ApiService.getUrl('/attendance/locations/');
      final response = await http.post(
        url,
        headers: ApiService.getHeaders(token),
        body: jsonEncode({
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'radius_meters': radiusMeters,
          'is_active': isActive,
        }),
      );

      final responseData = ApiService.handleResponse(response);
      return CheckInLocation.fromJson(responseData);
    } catch (e) {
      throw Exception('create_location_error');
    }
  }

  static Future<void> updateCheckInLocation(
    String token,
    int locationId, {
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isActive,
  }) async {
    try {
      final url = ApiService.getUrl('/attendance/locations/$locationId/');
      final Map<String, dynamic> data = {};
      
      if (name != null) data['name'] = name;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (radiusMeters != null) data['radius_meters'] = radiusMeters;
      if (isActive != null) data['is_active'] = isActive;

      final response = await http.put(
        url,
        headers: ApiService.getHeaders(token),
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        throw Exception('update_location_failed');
      }
    } catch (e) {
      throw Exception('update_location_error');
    }
  }

  static Future<void> deleteCheckInLocation(String token, int locationId) async {
    try {
      final url = ApiService.getUrl('/attendance/locations/$locationId/');
      final response = await http.delete(
        url,
        headers: ApiService.getHeaders(token),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('delete_location_failed');
      }
    } catch (e) {
      throw Exception('delete_location_error');
    }
  }

  static Future<String> generateQRCode(String token, int locationId) async {
    try {
      final url = ApiService.getUrl('/attendance/qr-generate/');
      final response = await http.post(
        url,
        headers: ApiService.getHeaders(token),
        body: jsonEncode({'location_id': locationId}),
      );

      final responseData = ApiService.handleResponse(response);
      return responseData['qr_data'] ?? '';
    } catch (e) {
      throw Exception('qr_code_generation_error');
    }
  }

  static Future<AttendanceRecord> recordAttendanceWithQR(
    String token,
    String qrData,
    double latitude,
    double longitude,
  ) async {
    try {
      final url = ApiService.getUrl('/attendance/qr-checkin/');
      final response = await http.post(
        url,
        headers: ApiService.getHeaders(token),
        body: jsonEncode({
          'qr_data': qrData,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      final responseData = ApiService.handleResponse(response);
      return AttendanceRecord.fromJson(responseData);
    } catch (e) {
      throw Exception('attendance_record_error');
    }
  }

  static Future<Map<String, dynamic>> getCurrentAttendanceStatus(String token) async {
    try {
      final url = ApiService.getUrl('/attendance/current-status/');
      final response = await http.get(
        url,
        headers: ApiService.getHeaders(token),
      );

      return ApiService.handleResponse(response);
    } catch (e) {
      debugPrint('getCurrentAttendanceStatus error: $e');
      return {
        'is_checked_in': false,
        'last_check_in': null,
        'last_check_out': null,
      };
    }
  }

  static Future<List<AttendanceRecord>> fetchAttendanceHistory(
    String token, {
    String? startDate,
    String? endDate,
    int? userId,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (userId != null) queryParams['user_id'] = userId.toString();

      final url = ApiService.getUrl('/attendance/history/')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      
      final response = await http.get(
        url,
        headers: ApiService.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => AttendanceRecord.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('fetch_history_failed');
      }
    } catch (e) {
      throw Exception('fetch_history_error');
    }
  }
}
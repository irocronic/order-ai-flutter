// lib/services/offline_attendance_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/attendance_record.dart';
import '../services/connectivity_service.dart';
import '../services/attendance_service.dart';
import '../services/user_session.dart';

class OfflineAttendanceService {
  static const String _offlineRecordsKey = 'offline_attendance_records';
  static const String _lastSyncKey = 'last_attendance_sync';

  /// İnternet olmadığında yerel kayıt
  static Future<void> saveOfflineRecord(Map<String, dynamic> recordData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRecords = await getOfflineRecords();
      
      // Timestamp ekle
      recordData['offline_timestamp'] = DateTime.now().toIso8601String();
      recordData['sync_status'] = 'pending';
      
      existingRecords.add(recordData);
      
      final jsonString = jsonEncode(existingRecords);
      await prefs.setString(_offlineRecordsKey, jsonString);
      
      debugPrint('Offline attendance record saved: ${recordData['type']}');
    } catch (e) {
      debugPrint('Error saving offline record: $e');
      throw Exception('offline_save_error: $e');
    }
  }

  /// Kaydedilmiş offline kayıtları getir
  static Future<List<Map<String, dynamic>>> getOfflineRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_offlineRecordsKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error getting offline records: $e');
      return [];
    }
  }

  /// İnternet döndüğünde senkronizasyon
  static Future<SyncResult> syncOfflineRecords() async {
    if (!UserSession.token.isNotEmpty) {
      return SyncResult(success: false, message: 'token_not_found');
    }

    final records = await getOfflineRecords();
    
    if (records.isEmpty) {
      return SyncResult(success: true, message: 'no_records_to_sync');
    }

    int successCount = 0;
    int failureCount = 0;
    List<String> errors = [];

    for (final record in records) {
      try {
        if (record['sync_status'] == 'synced') {
          successCount++;
          continue;
        }

        await AttendanceService.recordAttendanceWithQR(
          UserSession.token,
          record['qr_data'] as String,
          record['latitude'] as double,
          record['longitude'] as double,
        );
        
        record['sync_status'] = 'synced';
        record['synced_at'] = DateTime.now().toIso8601String();
        successCount++;
        
      } catch (e) {
        debugPrint('Failed to sync record: $e');
        record['sync_status'] = 'failed';
        record['error'] = e.toString();
        failureCount++;
        errors.add(e.toString());
      }
    }

    // Başarılı kayıtları temizle
    final pendingRecords = records.where((r) => r['sync_status'] != 'synced').toList();
    await _saveRecords(pendingRecords);
    
    // Son sync zamanını kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

    return SyncResult(
      success: failureCount == 0,
      message: 'sync_result_message',
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
    );
  }

  /// Tüm offline kayıtları temizle
  static Future<void> clearOfflineRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineRecordsKey);
    debugPrint('All offline records cleared');
  }

  /// Başarısız olanları temizle
  static Future<void> clearFailedRecords() async {
    final records = await getOfflineRecords();
    final validRecords = records.where((r) => r['sync_status'] != 'failed').toList();
    await _saveRecords(validRecords);
  }

  /// Son senkronizasyon zamanını getir
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeString = prefs.getString(_lastSyncKey);
    
    if (timeString == null) return null;
    
    try {
      return DateTime.parse(timeString);
    } catch (e) {
      return null;
    }
  }

  /// Offline kayıt sayısını getir
  static Future<int> getOfflineRecordCount() async {
    final records = await getOfflineRecords();
    return records.where((r) => r['sync_status'] == 'pending').length;
  }

  /// İnternet bağlantısını kontrol et ve otomatik sync yap
  static Future<void> autoSyncIfOnline() async {
    // ConnectivityService'den boolean dönen method kullanın
    if (await ConnectivityService.instance.isOnline) {
      final recordCount = await getOfflineRecordCount();
      if (recordCount > 0) {
        debugPrint('Auto-syncing $recordCount offline records...');
        await syncOfflineRecords();
      }
    }
  }

  /// Private helper method
  static Future<void> _saveRecords(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    if (records.isEmpty) {
      await prefs.remove(_offlineRecordsKey);
    } else {
      final jsonString = jsonEncode(records);
      await prefs.setString(_offlineRecordsKey, jsonString);
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int successCount;
  final int failureCount;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    this.successCount = 0,
    this.failureCount = 0,
    this.errors = const [],
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, message: $message)';
  }
}
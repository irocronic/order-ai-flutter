// lib/services/admin_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import 'api_service.dart';

class AdminService {
  /// Tüm işletme sahiplerini listeler.
  static Future<List<dynamic>> fetchBusinessOwners(String token) async {
    // DÜZELTME: URL /admin-panel/ içerecek şekilde güncellendi
    final url = ApiService.getUrl('/admin-panel/manage-users/business-owners/');
    debugPrint("AdminService: Fetching business owners from $url");
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('Fetch Business Owners API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('İşletme sahipleri alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Fetch Business Owners Network Error: $e');
      throw Exception('İşletme sahipleri çekilirken hata: $e');
    }
  }

  /// Belirli bir işletme sahibine ait personeli listeler.
  static Future<List<dynamic>> fetchStaffForOwner(String token, int ownerId) async {
    // DÜZELTME: URL /admin-panel/ içerecek şekilde güncellendi
    final url = ApiService.getUrl('/admin-panel/manage-users/$ownerId/staff/');
    debugPrint("AdminService: Fetching staff for owner $ownerId from $url");
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('Fetch Staff for Owner API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('Personel listesi alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Fetch Staff for Owner Network Error: $e');
      throw Exception('Personel listesi çekilirken hata: $e');
    }
  }

  /// Bir kullanıcının aktiflik durumunu günceller.
  static Future<Map<String, dynamic>> setUserActiveStatus(String token, int userId, bool isActive) async {
    // DÜZELTME: URL /admin-panel/ içerecek şekilde güncellendi
    final url = ApiService.getUrl('/admin-panel/manage-users/$userId/set-active/');
    debugPrint("AdminService: Setting active status for user $userId to $isActive via $url");
    try {
      final response = await http.patch(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({'is_active': isActive}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('Set User Active Status API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('Kullanıcı aktiflik durumu güncellenemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Set User Active Status Network Error: $e');
      throw Exception('Kullanıcı aktiflik durumu güncellenirken hata: $e');
    }
  }

  /// Bir kullanıcı hesabını siler.
  static Future<void> deleteUserAccount(String token, int userId) async {
    final url = ApiService.getUrl('/admin-panel/manage-users/$userId/delete-user/');
    debugPrint("AdminService: Deleting user $userId via $url");
    try {
      final response = await http.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 204) {
        return;
      } else {
        debugPrint('Delete User Account API Error (${response.statusCode}): ${response.body.isNotEmpty ? utf8.decode(response.bodyBytes) : "No content"}');
        throw Exception('Kullanıcı silinemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Delete User Account Network Error: $e');
      throw Exception('Kullanıcı silinirken hata: $e');
    }
  }

  /// Onay bekleyen kullanıcıları listeler.
  static Future<List<dynamic>> fetchPendingApprovalUsers(String token) async {
    final url = ApiService.getUrl('/admin-panel/manage-users/pending-approvals/');
    debugPrint("AdminService: Fetching pending approval users from $url");
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('Fetch Pending Approval Users API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('Onay bekleyen kullanıcılar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Fetch Pending Approval Users Network Error: $e');
      throw Exception('Onay bekleyen kullanıcılar çekilirken hata: $e');
    }
  }

  /// Belirli bir kullanıcıyı onaylar.
  static Future<Map<String, dynamic>> approveUser(String token, int userId) async {
    // DÜZELTME: URL /admin-panel/ içerecek şekilde güncellendi
    final url = ApiService.getUrl('/admin-panel/manage-users/$userId/approve/');
    debugPrint("AdminService: Approving user $userId via $url");
    try {
      final response = await http.post(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        debugPrint('Approve User API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('Kullanıcı onaylanamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Approve User Network Error: $e');
      throw Exception('Kullanıcı onaylanırken hata: $e');
    }
  }
}
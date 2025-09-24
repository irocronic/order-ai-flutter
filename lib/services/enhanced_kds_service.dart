// lib/services/enhanced_kds_service.dart (KdsService'e eklenecek metodlar)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class EnhancedKdsService {
  // Existing KdsService methods...
  
  // 🔥 Enhanced KDS action methods with better error handling
  
  static Future<http.Response> markOrderItemPreparing(
    String token,
    int orderId,
    int orderItemId,
  ) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/kds/order-items/$orderItemId/preparing/');
      
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'order_id': orderId,
          'kds_status': 'preparing_kds',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));
      
      return response;
    } catch (e) {
      throw Exception('Failed to mark item as preparing: $e');
    }
  }

  static Future<http.Response> markOrderItemReady(
    String token,
    int orderId,
    int orderItemId,
  ) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/kds/order-items/$orderItemId/ready/');
      
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'order_id': orderId,
          'kds_status': 'ready_kds',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));
      
      return response;
    } catch (e) {
      throw Exception('Failed to mark item as ready: $e');
    }
  }

  static Future<http.Response> markOrderItemPickedUp(
    String token,
    int orderId,
    int orderItemId,
  ) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/kds/order-items/$orderItemId/picked-up/');
      
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'order_id': orderId,
          'kds_status': 'picked_up_kds',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));
      
      return response;
    } catch (e) {
      throw Exception('Failed to mark item as picked up: $e');
    }
  }

  static Future<http.Response> approveOrder(
    String token,
    int orderId,
  ) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/kds/orders/$orderId/approve/');
      
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': 'approved',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));
      
      return response;
    } catch (e) {
      throw Exception('Failed to approve order: $e');
    }
  }

  static Future<http.Response> rejectOrder(
    String token,
    int orderId,
    String reason,
  ) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/kds/orders/$orderId/reject/');
      
      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'status': 'rejected',
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 15));
      
      return response;
    } catch (e) {
      throw Exception('Failed to reject order: $e');
    }
  }
}
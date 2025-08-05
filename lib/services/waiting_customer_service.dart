// lib/services/waiting_customer_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint için eklendi
import 'package:http/http.dart' as http;
import 'api_service.dart';

class WaitingCustomerService {
  static Future<http.Response> fetchCustomers(String token) {
    final url = ApiService.getUrl('/waiting_customers/');
    return http.get(url, headers: {"Authorization": "Bearer $token"});
  }
  static Future<http.Response> addCustomer(
    String token,
    String name,
    String phone,
    int partySize,
    String? notes,
  ) {
    final url = ApiService.getUrl('/waiting_customers/');
    Map<String, dynamic> payload = {
      "name": name,
      "phone": phone,
      "is_waiting": true,
      "party_size": partySize,
    };
    if (notes != null && notes.isNotEmpty) {
      payload["notes"] = notes;
    }
    debugPrint("[WaitingCustomerService] addCustomer payload: ${jsonEncode(payload)}");
    return http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(payload),
    );
  }

  // GÜNCELLENDİ: partySize ve notes eklendi
  static Future<http.Response> updateCustomer(
    String token,
    int customerId,
    String name,
    String phone,
    bool isWaiting,
    int partySize, // YENİ
    String? notes,  // YENİ (opsiyonel olabilir)
  ) {
    final url = ApiService.getUrl('/waiting_customers/$customerId/');
    Map<String, dynamic> payload = {
      "name": name,
      "phone": phone,
      "is_waiting": isWaiting,
      "party_size": partySize,
    };
    if (notes != null) { // Not boş gönderilebilmeli (silmek için)
      payload["notes"] = notes;
    }
    debugPrint("[WaitingCustomerService] updateCustomer payload for ID $customerId: ${jsonEncode(payload)}");
    return http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode(payload),
    );
  }

  static Future<http.Response> deleteCustomer(String token, int customerId) {
    final url = ApiService.getUrl('/waiting_customers/$customerId/');
    return http.delete(
      url,
      headers: {"Authorization": "Bearer $token"},
    );
  }
}
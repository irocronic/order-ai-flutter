// lib/services/procurement_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/supplier.dart';
import '../models/purchase_order.dart';

class ProcurementService {
  // --- Supplier Methods ---

  static Future<List<Supplier>> fetchSuppliers(String token) async {
    final response = await http.get(
      ApiService.getUrl('/suppliers/'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Supplier.fromJson(json)).toList();
    } else {
      throw Exception('Tedarikçiler yüklenemedi: ${response.statusCode}');
    }
  }

  static Future<Supplier> createSupplier(String token, Map<String, dynamic> supplierData) async {
    final response = await http.post(
      ApiService.getUrl('/suppliers/'),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode(supplierData),
    );
    if (response.statusCode == 201) {
      return Supplier.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Tedarikçi oluşturulamadı: ${utf8.decode(response.bodyBytes)}');
    }
  }

  static Future<Supplier> updateSupplier(String token, int supplierId, Map<String, dynamic> supplierData) async {
    final response = await http.put(
      ApiService.getUrl('/suppliers/$supplierId/'),
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode(supplierData),
    );
    if (response.statusCode == 200) {
      return Supplier.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Tedarikçi güncellenemedi: ${utf8.decode(response.bodyBytes)}');
    }
  }
  
  static Future<void> deleteSupplier(String token, int supplierId) async {
    final response = await http.delete(
      ApiService.getUrl('/suppliers/$supplierId/'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode != 204) {
      throw Exception('Tedarikçi silinemedi: ${response.statusCode}');
    }
  }

  // --- Purchase Order Methods ---

  static Future<List<PurchaseOrder>> fetchPurchaseOrders(String token) async {
    final response = await http.get(
      ApiService.getUrl('/purchase-orders/'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => PurchaseOrder.fromJson(json)).toList();
    } else {
      throw Exception('Alım siparişleri yüklenemedi: ${response.statusCode}');
    }
  }

  // ==================== GÜNCELLENECEK METOT ====================
  static Future<PurchaseOrder> createPurchaseOrder(String token, Map<String, dynamic> orderData) async {
    try {
      // *** YENİ: Order items'da supplier_id bilgisini ekle ***
      if (orderData['items'] is List && orderData['supplier'] != null) {
        final supplierId = orderData['supplier'];
        
        // Her malzeme için supplier_id'yi ekle (backend tarafından kullanılacak)
        for (var item in orderData['items']) {
          if (item is Map<String, dynamic>) {
            item['supplier_id'] = supplierId;
          }
        }
        
        print('[ProcurementService] 📦 Purchase Order Data with Supplier: $orderData');
      }
      
      final response = await http.post(
        ApiService.getUrl('/purchase-orders/'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(orderData),
      );
      
      if (response.statusCode == 201) {
        final result = PurchaseOrder.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
        print('[ProcurementService] ✅ Purchase Order created successfully: ${result.id}');
        return result;
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        print('[ProcurementService] ❌ Purchase Order creation failed: $errorBody');
        throw Exception('Alım siparişi oluşturulamadı: $errorBody');
      }
    } catch (e) {
      print('[ProcurementService] ❌ Exception during purchase order creation: $e');
      throw Exception('Alım siparişi oluşturulurken hata: $e');
    }
  }
  // ==========================================================
  
  static Future<void> cancelPurchaseOrder(String token, int orderId) async {
    final response = await http.post(
      ApiService.getUrl('/purchase-orders/$orderId/cancel/'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Alım siparişi iptal edilemedi: ${response.statusCode}');
    }
  }

  static Future<PurchaseOrder> markPurchaseOrderAsCompleted(String token, int orderId) async {
    final response = await http.post(
      ApiService.getUrl('/purchase-orders/$orderId/complete/'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      return PurchaseOrder.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Sipariş tamamlandı olarak işaretlenemedi: ${response.statusCode}');
    }
  }

  // ==================== YENİ METOT: Ingredient-Supplier İlişkisi ====================
  static Future<void> assignSupplierToIngredients(String token, int supplierId, List<int> ingredientIds) async {
    try {
      final response = await http.post(
        ApiService.getUrl('/ingredients/assign-supplier/'),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({
          'supplier_id': supplierId,
          'ingredient_ids': ingredientIds,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Malzeme-tedarikçi ataması başarısız: ${response.statusCode}');
      }
      
      print('[ProcurementService] ✅ Ingredients assigned to supplier successfully');
    } catch (e) {
      print('[ProcurementService] ❌ Failed to assign supplier to ingredients: $e');
      throw Exception('Malzeme-tedarikçi ataması sırasında hata: $e');
    }
  }
  // =====================================================================
}
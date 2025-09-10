// lib/services/ingredient_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/ingredient.dart';
import '../models/unit_of_measure.dart';
import '../models/ingredient_stock_movement.dart';

class IngredientService {
  // Hata Düzeltmesi: getHeaders metodu bu servis içinde yerel olarak tanımlandı.
  static Map<String, String> getHeaders(String token) {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Ingredient>> fetchIngredients(String token) async {
    final response = await http.get(
      ApiService.getUrl('/ingredients/'),
      headers: getHeaders(token),
    );
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Ingredient.fromJson(json)).toList();
    } else {
      throw Exception('Malzemeler alınamadı. Hata: ${response.statusCode}');
    }
  }

  static Future<List<UnitOfMeasure>> fetchUnits(String token) async {
    final response = await http.get(
      ApiService.getUrl('/units-of-measure/'),
      headers: getHeaders(token),
    );
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => UnitOfMeasure.fromJson(json)).toList();
    } else {
      throw Exception('Ölçü birimleri alınamadı. Hata: ${response.statusCode}');
    }
  }

  static Future<void> createIngredient({
    required String token,
    required String name,
    required double stockQuantity,
    required int unitId,
  }) async {
    final response = await http.post(
      ApiService.getUrl('/ingredients/'),
      headers: getHeaders(token),
      body: jsonEncode({
        'name': name,
        'stock_quantity': stockQuantity.toString(),
        'unit_id': unitId,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Malzeme oluşturulamadı: ${utf8.decode(response.bodyBytes)}');
    }
  }

  static Future<void> adjustStock({
    required String token,
    required int ingredientId,
    required String movementType,
    required double quantityChange,
    String? description,
  }) async {
    final response = await http.post(
      ApiService.getUrl('/ingredients/$ingredientId/adjust-stock/'),
      headers: getHeaders(token),
      body: jsonEncode({
        'movement_type': movementType,
        'quantity_change': quantityChange,
        'description': description,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Stok ayarlanamadı: ${utf8.decode(response.bodyBytes)}');
    }
  }

  static Future<List<IngredientStockMovement>> fetchIngredientHistory(
      String token, int ingredientId) async {
    final response = await http.get(
      ApiService.getUrl('/ingredients/$ingredientId/history/'),
      headers: getHeaders(token),
    );
    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => IngredientStockMovement.fromJson(json)).toList();
    } else {
      throw Exception('Stok geçmişi alınamadı: ${response.statusCode}');
    }
  }

  static Future<void> sendLowStockEmailToSupplier({
    required String token,
    required int supplierId,
    required List<int> ingredientIds,
  }) async {
    final response = await http.post(
      ApiService.getUrl('/ingredients/send-low-stock-report/'),
      headers: getHeaders(token),
      body: jsonEncode({
        'supplier_id': supplierId,
        'ingredient_ids': ingredientIds,
      }),
    );
    if (response.statusCode != 202) {
      throw Exception('Tedarikçiye e-posta gönderilemedi: ${utf8.decode(response.bodyBytes)}');
    }
  }
}
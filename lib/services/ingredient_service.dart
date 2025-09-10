// lib/services/ingredient_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/ingredient.dart';
import '../models/unit_of_measure.dart';
import '../models/ingredient_stock_movement.dart';

class IngredientService {
  static Future<List<UnitOfMeasure>> fetchUnits(String token) async {
    final response = await http.get(
      ApiService.getUrl('/units-of-measure/'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => UnitOfMeasure.fromJson(json)).toList();
    } else {
      throw Exception('Ölçü birimleri yüklenemedi: ${response.statusCode}');
    }
  }

  static Future<List<Ingredient>> fetchIngredients(String token) async {
    final response = await http.get(
      ApiService.getUrl('/ingredients/'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Ingredient.fromJson(json)).toList();
    } else {
      throw Exception('Malzemeler yüklenemedi: ${response.statusCode}');
    }
  }

  static Future<Ingredient> createIngredient({
    required String token,
    required String name,
    required double stockQuantity,
    required int unitId,
    double? alertThreshold,
  }) async {
    final response = await http.post(
      ApiService.getUrl('/ingredients/'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        'name': name,
        'stock_quantity': stockQuantity,
        'unit_id': unitId,
        'alert_threshold': alertThreshold,
      }),
    );
    if (response.statusCode == 201) {
      return Ingredient.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Malzeme oluşturulamadı: ${utf8.decode(response.bodyBytes)}');
    }
  }
  
  static Future<Ingredient> adjustStock({
    required String token,
    required int ingredientId,
    required String movementType,
    required double quantityChange,
    String? description,
  }) async {
    final url = ApiService.getUrl('/ingredients/$ingredientId/adjust-stock/');
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        'movement_type': movementType,
        'quantity_change': quantityChange,
        'description': description,
      }),
    );

    if (response.statusCode == 200) {
      return Ingredient.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Malzeme stoğu güncellenemedi: ${utf8.decode(response.bodyBytes)}');
    }
  }

  static Future<List<IngredientStockMovement>> fetchIngredientHistory(String token, int ingredientId) async {
    final url = ApiService.getUrl('/ingredients/$ingredientId/history/');
    final response = await http.get(url, headers: {"Authorization": "Bearer $token"});

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => IngredientStockMovement.fromJson(json)).toList();
    } else {
      throw Exception('Stok geçmişi alınamadı: ${response.statusCode}');
    }
  }
}
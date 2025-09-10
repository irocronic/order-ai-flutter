// lib/services/recipe_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
// Gerekli modelleri import et...

class RecipeService {
  /// Bir varyantın reçetesini getirir.
  static Future<List<dynamic>> fetchRecipeForVariant(String token, int variantId) async {
    final url = ApiService.getUrl('/recipes/').replace(queryParameters: {'variant_id': variantId.toString()});
    final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Reçete alınamadı: ${response.statusCode}');
    }
  }

  /// Reçeteye yeni bir malzeme ekler.
  static Future<dynamic> addIngredientToRecipe(String token, int variantId, int ingredientId, double quantity) async {
    final url = ApiService.getUrl('/recipes/');
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      body: jsonEncode({
        'variant': variantId,
        'ingredient': ingredientId,
        'quantity': quantity,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Malzeme eklenemedi: ${utf8.decode(response.bodyBytes)}');
    }
  }

  /// Reçeteden bir malzemeyi siler.
  static Future<void> deleteRecipeItem(String token, int recipeItemId) async {
    final url = ApiService.getUrl('/recipes/$recipeItemId/');
    final response = await http.delete(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode != 204) {
      throw Exception('Malzeme silinemedi: ${response.statusCode}');
    }
  }
}
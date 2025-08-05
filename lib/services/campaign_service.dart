// lib/services/campaign_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/campaign_menu.dart';

class CampaignService {
  /// İşletmeye ait tüm kampanyaları getirir.
  static Future<List<CampaignMenu>> fetchCampaigns(String token, int businessId) async {
    final url = ApiService.getUrl('/campaigns/').replace(queryParameters: {'business_id': businessId.toString()});
    debugPrint("CampaignService: Fetching campaigns from $url");
    try {
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => CampaignMenu.fromJson(json)).toList();
      } else {
        debugPrint('Fetch Campaigns API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('Kampanyalar alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Fetch Campaigns Network Error: $e');
      throw Exception('Kampanyalar çekilirken hata: $e');
    }
  }

  /// Yeni bir kampanya oluşturur.
  static Future<CampaignMenu> createCampaign(String token, Map<String, dynamic> campaignData) async {
    final url = ApiService.getUrl('/campaigns/');
    debugPrint("CampaignService: Creating campaign with payload: ${jsonEncode(campaignData)}");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(campaignData),
      );
      if (response.statusCode == 201) {
        return CampaignMenu.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        debugPrint('Create Campaign API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('Kampanya oluşturulamadı: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('Create Campaign Network Error: $e');
      throw Exception('Kampanya oluşturulurken hata: $e');
    }
  }

  /// Mevcut bir kampanyayı günceller.
  static Future<CampaignMenu> updateCampaign(String token, int campaignId, Map<String, dynamic> campaignData) async {
    final url = ApiService.getUrl('/campaigns/$campaignId/');
    debugPrint("CampaignService: Updating campaign $campaignId with payload: ${jsonEncode(campaignData)}");
    try {
      final response = await http.put( // veya PATCH
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(campaignData),
      );
      if (response.statusCode == 200) {
        return CampaignMenu.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        debugPrint('Update Campaign API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception('Kampanya güncellenemedi: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
      }
    } catch (e) {
      debugPrint('Update Campaign Network Error: $e');
      throw Exception('Kampanya güncellenirken hata: $e');
    }
  }

  /// Bir kampanyayı siler.
  static Future<void> deleteCampaign(String token, int campaignId) async {
    final url = ApiService.getUrl('/campaigns/$campaignId/');
    debugPrint("CampaignService: Deleting campaign $campaignId");
    try {
      final response = await http.delete(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode != 204) {
        debugPrint('Delete Campaign API Error (${response.statusCode}): ${response.body}');
        throw Exception('Kampanya silinemedi: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Delete Campaign Network Error: $e');
      throw Exception('Kampanya silinirken hata: $e');
    }
  }
}
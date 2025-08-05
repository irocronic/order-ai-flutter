// lib/services/pager_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'api_service.dart';
import '../models/pager_device_model.dart';

class PagerService {
  PagerService._privateConstructor();
  static final PagerService instance = PagerService._privateConstructor();

  late AppLocalizations _l10n;

  void init(AppLocalizations l10n) {
    _l10n = l10n;
  }

  /// İşletmeye ait tüm kayıtlı çağrı cihazlarını ve durumlarını getirir.
  Future<List<PagerSystemDevice>> fetchPagers(String token) async {
    final url = ApiService.getUrl('/pagers/');
    debugPrint("PagerService: Fetching pagers from $url");
    try {
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((json) => PagerSystemDevice.fromJson(json)).toList();
      } else {
        debugPrint('Fetch Pagers API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception(_l10n.pagerServiceErrorFetch(response.statusCode.toString()));
      }
    } catch (e) {
      debugPrint('Fetch Pagers Network Error: $e');
      throw Exception(_l10n.pagerServiceErrorFetchGeneric(e.toString()));
    }
  }

  /// Yeni bir çağrı cihazı kaydeder.
  Future<PagerSystemDevice> createPager(String token, int businessId, String deviceId, {String? name, String? notes}) async {
    final url = ApiService.getUrl('/pagers/');
    final Map<String, dynamic> payload = {
      'business': businessId,
      'device_id': deviceId,
      'status': 'available',
    };
    if (name != null && name.isNotEmpty) payload['name'] = name;
    if (notes != null && notes.isNotEmpty) payload['notes'] = notes;

    debugPrint("PagerService: Creating pager with payload: ${jsonEncode(payload)}");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 201) {
        return PagerSystemDevice.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        debugPrint('Create Pager API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception(_l10n.pagerServiceErrorCreate(response.statusCode.toString(), utf8.decode(response.bodyBytes)));
      }
    } catch (e) {
      debugPrint('Create Pager Network Error: $e');
      throw Exception(_l10n.pagerServiceErrorCreateGeneric(e.toString()));
    }
  }

  /// Bir çağrı cihazının durumunu veya diğer bilgilerini günceller.
  Future<PagerSystemDevice> updatePager(String token, String pagerSystemModelId, {String? name, String? status, String? notes, int? orderIdToAssign}) async {
    final url = ApiService.getUrl('/pagers/$pagerSystemModelId/');
    final Map<String, dynamic> payload = {};
    if (name != null) payload['name'] = name;
    if (status != null) payload['status'] = status;
    if (notes != null) payload['notes'] = notes;
    
    if (status == 'in_use' && orderIdToAssign != null) {
        payload['current_order'] = orderIdToAssign;
    } else if (status != null && status != 'in_use') {
        payload['current_order'] = null;
    } else if (orderIdToAssign == null && status == 'available'){
        payload['current_order'] = null;
    }

    if (payload.isEmpty) {
      if (orderIdToAssign == null && status == null && name == null && notes == null) {
          debugPrint("Update Pager: Güncellenecek veri bulunamadı.");
          throw Exception(_l10n.pagerServiceErrorUpdateNoData);
      }
    }
    debugPrint("PagerService: Updating pager $pagerSystemModelId with payload: ${jsonEncode(payload)}");

    try {
      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        return PagerSystemDevice.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        debugPrint('Update Pager API Error (${response.statusCode}): ${utf8.decode(response.bodyBytes)}');
        throw Exception(_l10n.pagerServiceErrorUpdate(response.statusCode.toString(), utf8.decode(response.bodyBytes)));
      }
    } catch (e) {
      debugPrint('Update Pager Network Error: $e');
      throw Exception(_l10n.pagerServiceErrorUpdateGeneric(e.toString()));
    }
  }

  /// Bir çağrı cihazını sistemden siler.
  Future<void> deletePager(String token, String pagerSystemModelId) async {
    final url = ApiService.getUrl('/pagers/$pagerSystemModelId/');
    debugPrint("PagerService: Deleting pager $pagerSystemModelId");
    try {
      final response = await http.delete(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode != 204) {
        debugPrint('Delete Pager API Error (${response.statusCode}): ${response.body.isNotEmpty ? utf8.decode(response.bodyBytes) : "No content"}');
        throw Exception(_l10n.pagerServiceErrorDelete(response.statusCode.toString()));
      }
    } catch (e) {
      debugPrint('Delete Pager Network Error: $e');
      throw Exception(_l10n.pagerServiceErrorDeleteGeneric(e.toString()));
    }
  }
}
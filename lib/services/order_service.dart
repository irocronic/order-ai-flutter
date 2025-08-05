// lib/services/order_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'api_service.dart';
import '../models/menu_item.dart';
import '../models/menu_item_variant.dart';
import '../models/order.dart' as AppOrder;
import '../models/order_item.dart';
import '../models/paginated_response.dart';

import 'connectivity_service.dart';
import 'cache_service.dart';
import '../models/sync_queue_item.dart';
import 'user_session.dart';

class OrderService {
  /// Sipariş oluşturur. Çevrimdışı ise kuyruğa ekler.
  static Future<http.Response> createOrder({
    required String token,
    required AppOrder.Order order,
    dynamic offlineTableData,
  }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) {
      debugPrint("[OrderService] (Offline) createOrder. Sipariş senkronizasyon kuyruğuna ekleniyor.");
      
      final orderPayload = order.toJson();
      const uuid = Uuid();
      final tempOrderId = uuid.v4();
      debugPrint("[OrderService] (Offline) Geçici Sipariş ID oluşturuldu: $tempOrderId");

      final payloadJson = jsonEncode(orderPayload);
      final payloadBase64 = base64Encode(utf8.encode(payloadJson));
      final syncItem = SyncQueueItem(
        id: tempOrderId,
        type: 'create_order',
        payload: payloadBase64,
        createdAt: DateTime.now().toIso8601String(),
      );
      await CacheService.instance.addToSyncQueue(syncItem);
      debugPrint("[OrderService] (Offline) SyncQueueItem başarıyla Hive'a yazıldı. ID: ${syncItem.id}");

      final List<Map<String, dynamic>> richOrderItems = order.orderItems.map((item) {
        return item.toJsonForCard();
      }).toList();
      
      final Map<String, dynamic> temporaryOrderData = {
        'id': -1,
        'temp_id': tempOrderId,
        'table': order.table,
        'table_details': offlineTableData,
        'business': order.business,
        'order_type': order.orderType,
        'customer_name': order.customerName,
        'customer_phone': order.customerPhone,
        'is_paid': false,
        'is_split_table': order.isSplitTable,
        'table_users': order.tableUsers,
        'credit_details': null,
        'payment_info': null,
        'status': 'pending_sync',
        'status_display': 'Senkronizasyon Bekliyor',
        'created_at': DateTime.now().toIso8601String(),
        'taken_by_staff_username': UserSession.username,
        'order_items': richOrderItems,
        'assigned_pager_info': null,
      };
      
      await CacheService.instance.cacheTemporaryOrder(temporaryOrderData);

      final responseBodyString = jsonEncode({
        'detail': 'Bağlantı yok. Sipariş yerel olarak kaydedildi ve bağlantı kurulunca gönderilecek.',
        'offline': true,
        'data': temporaryOrderData
      });
      
      final responseBodyBytes = utf8.encode(responseBodyString);

      return http.Response.bytes(
        responseBodyBytes,
        201,
        headers: { 'Content-Type': 'application/json; charset=utf-8' }
      );
    }

    final url = ApiService.getUrl('/orders/');
    debugPrint("[OrderService] (Online) createOrder payload: ${jsonEncode(order.toJson())}");
    return await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(order.toJson()),
    );
  }
  
  // <<< GÜNCELLEME BAŞLANGICI: Metod imzası ve içeriği değiştirildi >>>
  /// Bir siparişi ödenmiş olarak işaretler. Çevrimdışı ise kuyruğa ekler.
  static Future<http.Response> markOrderAsPaid({
    required String token,
    required AppOrder.Order order, // Artık tam sipariş nesnesini alıyor
    required String paymentType,
    required double amount,
  }) async {
    final orderIdentifier = order.syncId; // syncId getter'ı doğru ID'yi (geçici veya kalıcı) döndürür

    if (ConnectivityService.instance.isOnlineNotifier.value) {
      debugPrint("[OrderService] (Online) markOrderAsPaid. Order ID: $orderIdentifier");
      final url = ApiService.getUrl('/orders/$orderIdentifier/mark-as-paid/');
      final Map<String, dynamic> payload = {
        'payment_type': paymentType,
        'amount': amount.toStringAsFixed(2),
      };
      return await http.post(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(payload),
      );
    } else {
      debugPrint("[OrderService] (Offline) markOrderAsPaid. Order Sync ID: $orderIdentifier. İşlem kuyruğa ekleniyor.");
      const uuid = Uuid();
      final tempPaymentId = uuid.v4();
      
      final syncPayload = {
        // CRITICAL CHANGE: Artık siparişin geçici/kalıcı syncId'si payload'a ekleniyor.
        'orderId': orderIdentifier,
        'payment_type': paymentType,
        'amount': amount.toStringAsFixed(2),
      };
      debugPrint("--- OFFLINE PAYMENT PAYLOAD ---");
      debugPrint("Order ID to be synced: $orderIdentifier (${orderIdentifier.runtimeType})");
      debugPrint("Payload map: $syncPayload");
      // --- END LOG ---
      
      final payloadJson = jsonEncode(syncPayload);
      final payloadBase64 = base64Encode(utf8.encode(payloadJson));
      final syncItem = SyncQueueItem(
        id: tempPaymentId,
        type: 'mark_as_paid',
        payload: payloadBase64,
        createdAt: DateTime.now().toIso8601String(),
      );
      await CacheService.instance.addToSyncQueue(syncItem);
      debugPrint("[OrderService] (Offline) 'mark_as_paid' kuyruğa eklendi. Sync ID: $tempPaymentId");

      // Önbellekteki siparişi 'ödendi' olarak güncelle
      final cacheBox = CacheService.instance.tempOrdersBox;
      Map<String, dynamic>? cachedOrder = Map<String, dynamic>.from(cacheBox.get(orderIdentifier.toString()) ?? {});
      
      if (cachedOrder.isNotEmpty) {
        cachedOrder['is_paid'] = true;
        cachedOrder['status'] = 'completed';
        cachedOrder['status_display'] = 'Tamamlandı (Senk. Bekliyor)';
        cachedOrder['payment_info'] = {
          'payment_type': paymentType,
          'amount': amount.toStringAsFixed(2),
          'payment_date': DateTime.now().toIso8601String(),
        };

        await CacheService.instance.updateCachedOrder(cachedOrder);
        debugPrint("[OrderService] (Offline) Önbellekteki sipariş #$orderIdentifier 'Ödendi' olarak işaretlendi.");
        
        final responseBodyString = jsonEncode({
          'offline': true,
          'detail': 'Ödeme yerel olarak kaydedildi. Bağlantı kurulunca senkronize edilecek.',
          'data': cachedOrder,
        });
        
        return http.Response.bytes(utf8.encode(responseBodyString), 200, headers: {'Content-Type': 'application/json; charset=utf-8'});
      } else {
        debugPrint("[OrderService] UYARI: Offline'da ödeme alınırken ana sipariş #$orderIdentifier önbellekte bulunamadı!");
        throw Exception("Çevrimdışı sipariş önbellekte bulunamadı.");
      }
    }
  }

  static Future<List<dynamic>> fetchMenuItems(String token) async {
    if (ConnectivityService.instance.isOnlineNotifier.value) {
      debugPrint("[OrderService] (Online) Menü öğeleri API'den okunuyor...");
      final url = ApiService.getUrl('/menu-items/');
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        await CacheService.instance.cacheData('menu_items', data);
        debugPrint("[OrderService] (Online) Menü öğeleri başarıyla çekildi ve önbelleğe alındı.");
        return data;
      } else {
        throw Exception('Menü öğeleri alınamadı: ${response.statusCode}');
      }
    } else {
      debugPrint("[OrderService] (Offline) Menü öğeleri önbellekten okunuyor.");
      final cachedData = CacheService.instance.getCachedData('menu_items');
      if (cachedData != null) {
        debugPrint("[OrderService] (Offline) Menü öğeleri önbellekten başarıyla okundu.");
        return cachedData;
      } else {
        throw Exception("Çevrimdışı moddasınız ve önbellekte menü verisi bulunamadı.");
      }
    }
  }

  static Future<List<dynamic>> fetchCategories(String token) async {
    if (ConnectivityService.instance.isOnlineNotifier.value) {
      debugPrint("[OrderService] (Online) Kategoriler API'den okunuyor...");
      final url = ApiService.getUrl('/categories/');
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        await CacheService.instance.cacheData('categories', data);
        debugPrint("[OrderService] (Online) Kategoriler başarıyla çekildi ve önbelleğe alındı.");
        return data;
      } else {
        throw Exception('Kategoriler alınamadı: ${response.statusCode}');
      }
    } else {
      debugPrint("[OrderService] (Offline) Kategoriler önbellekten okunuyor.");
      final cachedData = CacheService.instance.getCachedData('categories');
      if (cachedData != null) {
        debugPrint("[OrderService] (Offline) Kategoriler önbellekten başarıyla okundu.");
        return cachedData;
      } else {
        throw Exception("Çevrimdışı moddasınız ve önbellekte kategori verisi bulunamadı.");
      }
    }
  }
  
  static Future<List<dynamic>?> fetchPendingOrdersOnly(String token, int businessId) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) return [];
    try {
      final url = ApiService.getUrl('/orders/').replace(queryParameters: { 'is_paid': 'false', 'exclude_status': 'rejected,cancelled,completed', });
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('results')) {
          return decodedBody['results'];
        } else if (decodedBody is List) {
          return decodedBody;
        }
        return [];
      }
    } catch (e) {
      debugPrint("Sadece bekleyen siparişleri çekerken hata: $e");
    }
    return null;
  }
  
  static Future<int?> fetchWaitingCountOnly(String token) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) return 0;
    try {
      final response = await http.get(ApiService.getUrl('/waiting_customers/'), headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.length;
      }
    } catch (e) {
      debugPrint("Sadece bekleyen müşteri sayısını çekerken hata: $e");
    }
    return null;
  }
  
  static Future<http.Response> addNewOrderItem({
    required String token,
    required dynamic orderId,
    required MenuItem item,
    MenuItemVariant? variant,
    List<MenuItemVariant>? extras,
    String? tableUser,
    required int quantity,
  }) async {
    final payload = {
      'menu_item_id': item.id,
      'variant_id': variant?.id,
      'quantity': quantity,
      'table_user': tableUser,
      'extras': extras?.map((e) => {'variant': e.id, 'quantity': 1}).toList() ?? [],
    };

    if (ConnectivityService.instance.isOnlineNotifier.value) {
      debugPrint("[OrderService] (Online) addNewOrderItem. Order ID: $orderId");
      final url = ApiService.getUrl('/orders/$orderId/add-item/');
      return await http.post(
        url,
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode(payload),
      );
    } else {
      debugPrint("[OrderService] (Offline) addNewOrderItem. Ana Sipariş ID: $orderId. İşlem kuyruğa ekleniyor.");
      
      const uuid = Uuid();
      final tempItemId = uuid.v4();
      
      final cacheBox = CacheService.instance.tempOrdersBox;
      Map<String, dynamic>? cachedOrder;
      String? cacheKey;

      for (var key in cacheBox.keys) {
        final orderMap = cacheBox.get(key);
        if (orderMap != null) {
          if (orderMap['temp_id'] == orderId.toString() || orderMap['id'] == orderId) {
            cachedOrder = Map<String, dynamic>.from(orderMap);
            cacheKey = key.toString();
            debugPrint("[OrderService] (Offline) Önbellekteki sipariş bulundu. Key: $cacheKey, temp_id: ${cachedOrder['temp_id']}");
            break;
          }
        }
      }

      if (cachedOrder != null && cacheKey != null) {
        final String syncOrderId = cachedOrder['temp_id'];

        final syncPayload = {'orderId': syncOrderId, ...payload};
        final payloadJson = jsonEncode(syncPayload);
        final payloadBase64 = base64Encode(utf8.encode(payloadJson));
        final syncItem = SyncQueueItem(
          id: tempItemId,
          type: 'add_order_item',
          payload: payloadBase64,
          createdAt: DateTime.now().toIso8601String(),
        );
        await CacheService.instance.addToSyncQueue(syncItem);
        debugPrint("[OrderService] (Offline) 'add_order_item' kuyruğa eklendi. Ana Sipariş Temp ID: $syncOrderId");

        double itemPrice = variant?.price ?? 0.0;
        if(item.isCampaignBundle) {
          itemPrice = item.price ?? 0.0;
        } else if (extras != null) {
          itemPrice += extras.fold(0.0, (sum, extra) => sum + extra.price);
        }
        
        List<dynamic> currentItems = List<dynamic>.from(cachedOrder['order_items'] ?? []);
        currentItems.add({
          'id': -DateTime.now().millisecondsSinceEpoch,
          'quantity': quantity,
          'price': itemPrice.toStringAsFixed(2),
          'delivered': false,
          'is_awaiting_staff_approval': false,
          'menu_item': {'id': item.id, 'name': item.name, 'is_campaign_bundle': item.isCampaignBundle},
          'variant': variant != null ? {'id': variant.id, 'name': variant.name} : null,
          'extras': extras?.map((e) => {'variant': e.id, 'quantity': 1, 'variant_name': e.name, 'variant_price': e.price.toStringAsFixed(2)}).toList() ?? [],
        });
        cachedOrder['order_items'] = currentItems;

        await CacheService.instance.updateCachedOrder(cachedOrder);
        debugPrint("[OrderService] (Offline) Önbellekteki sipariş #$syncOrderId yeni ürün ile güncellendi.");
        
        final responseBodyString = jsonEncode({
          'offline': true,
          'detail': 'Ürün siparişe yerel olarak eklendi.',
          'data': cachedOrder,
        });
        
        return http.Response.bytes(utf8.encode(responseBodyString), 200, headers: {'Content-Type': 'application/json; charset=utf-8'});

      } else {
        debugPrint("[OrderService] UYARI: Offline'da ürün eklenirken ana sipariş #$orderId önbellekte bulunamadı!");
        throw Exception("Çevrimdışı sipariş önbellekte bulunamadı.");
      }
    }
  }
  
  static Future<http.Response> deleteOrderItem({
    required String token,
    required int orderItemId,
  }) async {
    if (ConnectivityService.instance.isOnlineNotifier.value) {
      final url = ApiService.getUrl('/order_items/$orderItemId/');
      return await http.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
    } else {
      debugPrint("[OrderService] (Offline) deleteOrderItem. İşlem kuyruğa ekleniyor. Item ID: $orderItemId");
      const uuid = Uuid();
      final syncItem = SyncQueueItem(
        id: uuid.v4(),
        type: 'delete_order_item',
        payload: base64Encode(utf8.encode(jsonEncode({'order_item_id': orderItemId}))),
        createdAt: DateTime.now().toIso8601String(),
      );
      await CacheService.instance.addToSyncQueue(syncItem);
      debugPrint("[OrderService] (Offline) 'delete_order_item' kuyruğa eklendi.");

      final cacheBox = CacheService.instance.tempOrdersBox;
      Map<String, dynamic>? cachedOrder;
      String? cacheKey;

      for (var key in cacheBox.keys) {
        final orderMap = cacheBox.get(key);
        if (orderMap != null) {
          final items = orderMap['order_items'] as List<dynamic>? ?? [];
          if (items.any((item) => item['id'] == orderItemId)) {
            cachedOrder = Map<String, dynamic>.from(orderMap);
            cacheKey = key.toString();
            break;
          }
        }
      }

      if (cachedOrder != null && cacheKey != null) {
        (cachedOrder['order_items'] as List).removeWhere((item) => item['id'] == orderItemId);
        await CacheService.instance.updateCachedOrder(cachedOrder);
        debugPrint("[OrderService] (Offline) Önbellekteki siparişten kalem #$orderItemId silindi.");
      } else {
        debugPrint("[OrderService] UYARI: Offline'da ürün silinirken kalem #$orderItemId önbellekte bulunamadı!");
      }

      return http.Response('', 204);
    }
  }
  
  static Future<http.Response> markOrderItemDelivered({ required String token, required int orderId, required int orderItemId, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda ürün teslim edilemez."); }
    final url = ApiService.getUrl('/orders/$orderId/deliver-item/');
    final String body = jsonEncode({'order_item_id': orderItemId});
    return await http.post( url, headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"}, body: body, );
  }

  static Future<http.Response> markItemPickedUpByWaiter({ required String token, required int orderItemId, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda bu işlem yapılamaz."); }
    final url = ApiService.getUrl('/order_items/$orderItemId/mark-picked-up/');
    return await http.post( url, headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"}, body: jsonEncode({}), );
  }
  
  static Future<PaginatedResponse<AppOrder.Order>> fetchCompletedOrdersPaginated({ required String token, int page = 1, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda tamamlanmış siparişlere ulaşılamaz."); }
    final url = ApiService.getUrl('/orders/').replace(queryParameters: {'is_paid': 'true', 'page': page.toString()});
    final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('results')) { return PaginatedResponse.fromJson(decodedBody, (json) => AppOrder.Order.fromJson(json)); } 
      else { throw Exception('API yanıtı beklenmedik bir formatta.'); }
    } else { throw Exception('Ödenmiş siparişler alınamadı: ${response.statusCode}'); }
  }

  static Future<PaginatedResponse<AppOrder.Order>> fetchCreditSales({ required String token, int page = 1, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda veresiye listesine ulaşılamaz."); }
    final url = ApiService.getUrl('/orders/credit-sales/').replace(queryParameters: {'page': page.toString()});
    final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map<String, dynamic>) { return PaginatedResponse.fromJson(decodedBody, (json) => AppOrder.Order.fromJson(json)); } 
      else { throw Exception('Veresiye siparişleri API yanıtı beklenmedik bir formatta.'); }
    } else { throw Exception('Veresiye siparişleri alınamadı: ${response.statusCode}'); }
  }

  static Future<http.Response> saveCreditPayment({ required String token, required int orderId, String? customerName, String? customerPhone, String? notes, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda veresiye kaydı oluşturulamz."); }
    final url = ApiService.getUrl('/orders/$orderId/credit/');
    final Map<String, dynamic> payload = {};
    if (customerName != null) payload['customer_name'] = customerName;
    if (customerPhone != null) payload['customer_phone'] = customerPhone;
    if (notes != null) payload['notes'] = notes;
    return await http.post( url, headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"}, body: jsonEncode(payload), );
  }
  
  static Future<http.Response> cancelOrder(String token, int orderId) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda sipariş iptal edilemez."); }
    final url = ApiService.getUrl('/orders/$orderId/');
    return await http.delete( url, headers: {"Authorization": "Bearer $token"}, );
  }

  static Future<http.Response> approveGuestOrder({ required String token, required int orderId, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda sipariş onaylanamaz."); }
    final url = ApiService.getUrl('/orders/$orderId/approve-guest-order/');
    return await http.post( url, headers: {"Authorization": "Bearer $token"}, );
  }

  static Future<http.Response> rejectGuestOrder({ required String token, required int orderId, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda sipariş reddedilemez."); }
    final url = ApiService.getUrl('/orders/$orderId/reject-guest-order/');
    return await http.post( url, headers: {"Authorization": "Bearer $token"}, );
  }

  static Future<http.Response> markOrderPickedUpByWaiter({ required String token, required int orderId, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda bu işlem yapılamaz."); }
    final url = ApiService.getUrl('/orders/$orderId/mark-picked-up-by-waiter/');
    return await http.post( url, headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"}, );
  }
  
  static Future<int> fetchActiveTableOrderCount(String token, int businessId) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) return 0;
    final url = ApiService.getUrl('/orders/').replace(queryParameters: { 'business_id': businessId.toString(), 'order_type': 'table', 'is_paid': 'false', 'exclude_status': 'rejected,cancelled,completed', });
    try {
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) { final decodedBody = jsonDecode(utf8.decode(response.bodyBytes)); if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('count')) { return decodedBody['count'] as int? ?? 0; } }
      return 0;
    } catch (e) { return 0; }
  }

  static Future<int> fetchActiveTakeawayOrderCount(String token, int businessId) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) {
      try {
        final offlineOrders = CacheService.instance.getTemporaryOrders();
        final offlineTakeawayOrders = offlineOrders.where((order) => order['order_type'] == 'takeaway' && order['is_paid'] != true).toList();
        return offlineTakeawayOrders.length;
      } catch (e) {
        return 0;
      }
    }
    final url = ApiService.getUrl('/orders/').replace(queryParameters: { 'business_id': businessId.toString(), 'order_type': 'takeaway', 'is_paid': 'false', 'exclude_status': 'rejected,cancelled,completed', });
    try {
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) { 
        final decodedBody = jsonDecode(utf8.decode(response.bodyBytes)); 
        if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('count')) { 
          return decodedBody['count'] as int? ?? 0;
        } 
      }
      return 0;
    } catch (e) { return 0; }
  }

  static Future<http.Response> updateOrder(String token, int orderId, Map<String, dynamic> data) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda sipariş güncellenemez."); }
    final url = ApiService.getUrl('/orders/$orderId/');
    return await http.patch( url, headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"}, body: jsonEncode(data), );
  }

  static Future<Map<String, dynamic>?> fetchOrderDetails({ required String token, required int orderId, }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) { throw Exception("Çevrimdışı modda sipariş detaylarına ulaşılamaz."); }
    final url = ApiService.getUrl('/orders/$orderId/');
    try {
      final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
      if (response.statusCode == 200) { return jsonDecode(utf8.decode(response.bodyBytes)); } else { return null; }
    } catch (e) { return null; }
  }

  static Future<PaginatedResponse<AppOrder.Order>> fetchTakeawayOrdersPaginated({
    required String token,
    int page = 1,
  }) async {
    if (!ConnectivityService.instance.isOnlineNotifier.value) {
      final offlineOrders = CacheService.instance.getTemporaryOrders()
          .where((order) => order['order_type'] == 'takeaway')
          .map((json) => AppOrder.Order.fromJson(json))
          .toList();
      
      return PaginatedResponse(
        count: offlineOrders.length,
        next: null,
        previous: null,
        results: offlineOrders,
      );
    }
    
    final url = ApiService.getUrl('/orders/').replace(queryParameters: {
      'order_type': 'takeaway',
      'is_paid': 'false',
      'exclude_status': 'rejected,cancelled,completed',
      'page': page.toString(),
    });

    final response = await http.get(url, headers: {"Authorization": "Bearer $token"});
    if (response.statusCode == 200) {
      final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      if (decodedBody is Map<String, dynamic>) {
        return PaginatedResponse.fromJson(decodedBody, (json) => AppOrder.Order.fromJson(json));
      } else {
        throw Exception('API yanıtı beklenmedik bir formatta.');
      }
    } else {
      throw Exception('Paket siparişler alınamadı: ${response.statusCode}');
    }
  }
}
// lib/controllers/new_order_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../models/menu_item.dart';
import '../models/menu_item_variant.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_item_extra.dart';
import '../services/order_service.dart';
import '../utils/notifiers.dart';
import '../main.dart';
import 'package:flutter/foundation.dart'; // debugPrint için

/// NewOrderScreen'in state'ini ve iş mantığını yönetir.
class NewOrderController {
  final String token;
  final int businessId;
  final Function(VoidCallback fn) onStateUpdate;
  final Function(String message, {bool isError}) showSnackBarCallback;
  final Function(bool success) popScreenCallback;

  List<MenuItem> menuItems = [];
  List<dynamic> categories = [];
  List<OrderItem> basket = [];
  bool isLoading = true;
  String errorMessage = '';
  bool? isSplitTable;
  List<String> tableOwners = [];
  double get basketTotal => _calculateBasketTotal();

  NewOrderController({
    required this.token,
    required this.businessId,
    required this.table,
    required this.onStateUpdate,
    required this.showSnackBarCallback,
    required this.popScreenCallback,
  });

  final dynamic table;

  Future<bool> initializeScreen() async {
    bool success = await fetchInitialData();
    return success && errorMessage.isEmpty;
  }

  Future<bool> fetchInitialData() async {
    _setLoading(true);
    errorMessage = '';

    try {
      final results = await Future.wait([
        OrderService.fetchMenuItems(token),
        OrderService.fetchCategories(token),
      ]);

      final menuData = results[0];
      final categoryData = results[1];
      
      menuItems = menuData.map((e) => MenuItem.fromJson(e)).toList();
      categories = categoryData;
      
      errorMessage = '';
      onStateUpdate(() {}); // UI'ı yeni verilerle güncelle
      return true;

    } catch (e) {
      errorMessage = "Veriler alınamadı: ${e.toString().replaceFirst("Exception: ", "")}";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void handleTableTypeSelected(bool isSplit, List<String> owners) {
    isSplitTable = isSplit;
    tableOwners = owners;
    basket.clear();
    onStateUpdate(() {});
  }

  void handleTableOwnersUpdated(List<String> owners) {
    tableOwners = owners;
    onStateUpdate(() {});
  }

  void addToBasket(MenuItem item, MenuItemVariant? variant, List<MenuItemVariant> extras, String? tableUser, int quantity) {
    String? currentTableUser = (isSplitTable == true) ? tableUser : null;

    double effectiveUnitPrice;
    List<OrderItemExtra> orderItemExtras = [];
    MenuItemVariant? finalVariant = variant;

    if (item.isCampaignBundle) {
      effectiveUnitPrice = item.price ?? 0.0;
      finalVariant = null;
    } else {
      effectiveUnitPrice = variant?.price ?? 0.0;
      for (var extraVariant in extras) {
        effectiveUnitPrice += extraVariant.price;
        orderItemExtras.add(OrderItemExtra(
          id: 0,
          variant: extraVariant.id,
          name: extraVariant.name,
          price: extraVariant.price,
          quantity: 1,
        ));
      }
    }

    final index = basket.indexWhere((orderItem) {
      bool sameItem = orderItem.menuItem.id == item.id;
      bool sameVariantLogic;
      if (item.isCampaignBundle) {
        sameVariantLogic = orderItem.menuItem.isCampaignBundle;
      } else {
        sameVariantLogic = (finalVariant?.id == orderItem.variant?.id);
      }
      bool sameTableUserLogic = orderItem.tableUser == currentTableUser;
      bool sameExtrasLogic = true;
      if (!item.isCampaignBundle) {
        List<Map<String, dynamic>> existingExtrasMap = (orderItem.extras ?? []).map((e) => {'variant': e.variant, 'quantity': e.quantity}).toList();
        existingExtrasMap.sort((a, b) => (a['variant'] as int).compareTo(b['variant'] as int));
        List<Map<String, dynamic>> newExtrasMap = orderItemExtras.map((e) => {'variant': e.variant, 'quantity': e.quantity}).toList();
        newExtrasMap.sort((a, b) => (a['variant'] as int).compareTo(b['variant'] as int));
        sameExtrasLogic = const DeepCollectionEquality().equals(existingExtrasMap, newExtrasMap);
      }
      return sameItem && sameVariantLogic && sameTableUserLogic && sameExtrasLogic;
    });

    if (index != -1) {
      basket[index].quantity += quantity;
    } else {
      basket.add(OrderItem(
        menuItem: item,
        variant: finalVariant,
        price: effectiveUnitPrice,
        quantity: quantity,
        extras: item.isCampaignBundle ? [] : orderItemExtras,
        tableUser: currentTableUser,
      ));
    }
    onStateUpdate(() {});
  }

  void removeFromBasket(OrderItem item) {
    basket.remove(item);
    onStateUpdate(() {});
  }

  double _calculateBasketTotal() {
    double total = 0;
    for (var orderItem in basket) {
      total += orderItem.price * orderItem.quantity;
    }
    return total;
  }

  Future<void> handleCreateOrder() async {
    if (basket.isEmpty) {
      showSnackBarCallback("Lütfen en az bir ürün ekleyin.", isError: true);
      return;
    }
    if (isSplitTable == true && tableOwners.where((name) => name.trim().isNotEmpty).length < 2) {
      showSnackBarCallback("Bölünmüş masa için en az 2 masa sahibi adı girilmelidir.", isError: true);
      return;
    }

    _setLoading(true);
    errorMessage = '';

    Order newOrder = Order(
      table: table['id'],
      business: businessId,
      orderItems: basket,
      tableUsers: (isSplitTable == true && tableOwners.isNotEmpty)
          ? tableOwners.map((name) => {'name': name}).toList()
          : null,
      customerName: null,
      customerPhone: null,
      orderType: 'table',
    );

    debugPrint('NewOrderController: handleCreateOrder - Sipariş gönderiliyor: ${jsonEncode(newOrder.toJson())}');

    try {
      debugPrint("[Controller] 1. OrderService.createOrder çağrılacak.");
      final response = await OrderService.createOrder(
        token: token,
        order: newOrder,
      );
      debugPrint("[Controller] 2. OrderService.createOrder yanıt verdi. StatusCode: ${response.statusCode}");

      final responseBodyBytes = response.bodyBytes;
      debugPrint("[Controller] 3. Yanıtın bodyBytes alındı. Uzunluk: ${responseBodyBytes.length}");

      final decodedString = utf8.decode(responseBodyBytes);
      debugPrint("[Controller] 4. Yanıt body'si utf8.decode ile çözüldü.");
      
      if (response.statusCode == 201) {
        debugPrint("[Controller] 5. StatusCode 201, başarı bloğuna girildi.");
        String successMessage = "Sipariş başarıyla oluşturuldu.";
        bool isOffline = false;
        
        try {
          debugPrint("[Controller] 6. Yanıt gövdesi jsonDecode ile parse ediliyor...");
          final decodedBody = jsonDecode(decodedString);
          debugPrint("[Controller] 7. Yanıt gövdesi başarıyla parse edildi.");
          if(decodedBody is Map && decodedBody['offline'] == true) {
            isOffline = true;
            successMessage = decodedBody['detail'] ?? successMessage;
          }
        } catch(jsonError) {
          debugPrint("[Controller] UYARI: Offline yanıtı parse edilemedi, ancak devam ediliyor. Hata: $jsonError");
        }
        
        debugPrint("[Controller] 8. SnackBar gösterilecek: '$successMessage'");
        showSnackBarCallback(successMessage, isError: false);
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint("[Controller] 9. Ekran pop ediliyor.");
        popScreenCallback(true);

      } else {
        errorMessage = "Sipariş oluşturulurken hata oluştu (${response.statusCode}): ${utf8.decode(response.bodyBytes)}";
        showSnackBarCallback(errorMessage, isError: true);
      }
    } catch (e, s) { // Stack trace de yakala
      debugPrint("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      debugPrint("[Controller] KRİTİK HATA: _handleCreateOrder CATCH bloğuna düşüldü.");
      debugPrint("Hata Türü: ${e.runtimeType}");
      debugPrint("Hata Mesajı: $e");
      debugPrint("Stack Trace:\n$s");
      debugPrint("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      errorMessage = "Sipariş oluşturma hatası (detaylı log): $e";
      showSnackBarCallback(errorMessage, isError: true);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (isLoading == value) return;
    isLoading = value;
    onStateUpdate(() {});
  }
}
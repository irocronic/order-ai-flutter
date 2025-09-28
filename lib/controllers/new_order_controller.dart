// lib/controllers/new_order_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/menu_item.dart';
import '../models/menu_item_variant.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_item_extra.dart';
import '../services/order_service.dart';
import '../utils/notifiers.dart';
import '../main.dart';
import 'package:flutter/foundation.dart'; // debugPrint için

class NewOrderController {
  final String token;
  final int businessId;
  final Function(VoidCallback fn) onStateUpdate;
  final Function(String message, {bool isError}) showSnackBarCallback;
  final AppLocalizations l10n;

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
    required this.l10n,
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
      onStateUpdate(() {});
      return true;
    } catch (e) {
      errorMessage = l10n.errorFetchingData(e.toString().replaceFirst("Exception: ", ""));
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

  Future<bool> handleCreateOrder() async {
    if (basket.isEmpty) {
      showSnackBarCallback(l10n.errorAddAtLeastOneProduct, isError: true);
      return false;
    }
    if (isSplitTable == true && tableOwners.where((name) => name.trim().isNotEmpty).length < 2) {
      showSnackBarCallback(l10n.errorSplitTableMinTwoOwners, isError: true);
      return false;
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
    debugPrint('[NewOrderController] handleCreateOrder - Sipariş gönderiliyor: ${jsonEncode(newOrder.toJson())}');

    try {
      debugPrint("[Controller] 1. OrderService.createOrder çağrılacak.");
      final response = await OrderService.createOrder(
        token: token,
        order: newOrder,
      );
      debugPrint("[Controller] 2. OrderService.createOrder yanıt verdi. StatusCode: ${response.statusCode}");

      final responseBodyBytes = response.bodyBytes;
      final decodedString = utf8.decode(responseBodyBytes);
      if (response.statusCode == 201) {
        String successMessage = l10n.infoOrderCreatedSuccessfully;
        try {
          final decodedBody = jsonDecode(decodedString);
          if(decodedBody is Map && decodedBody['offline'] == true) {
            successMessage = decodedBody['detail'] ?? successMessage;
          }
        } catch(jsonError) {
          debugPrint("[Controller] UYARI: Offline yanıtı parse edilemedi, ancak devam ediliyor. Hata: $jsonError");
        }

        showSnackBarCallback(successMessage, isError: false);
        await Future.delayed(const Duration(milliseconds: 500));

        debugPrint("[Controller] 9. İşlem başarılı, 'true' döndürülüyor.");
        return true;
      } else {
        errorMessage = l10n.errorCreatingOrderWithDetails(response.statusCode.toString(), utf8.decode(response.bodyBytes));
        showSnackBarCallback(errorMessage, isError: true);
        return false;
      }
    } catch (e, s) {
      debugPrint("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      debugPrint("[Controller] KRİTİK HATA: _handleCreateOrder CATCH bloğuna düşüldü.");
      debugPrint("Hata Türü: ${e.runtimeType}");
      debugPrint("Hata Mesajı: $e");
      debugPrint("Stack Trace:\n$s");
      debugPrint("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      errorMessage = l10n.errorCreatingOrderGeneric(e.toString());
      showSnackBarCallback(errorMessage, isError: true);
      return false;
    } finally {
      _setLoading(false);
      debugPrint('[Controller] finally bloğu çalıştı, isLoading false olarak ayarlandı.');
    }
  }

  void _setLoading(bool value) {
    if (isLoading == value) return;
    isLoading = value;
    debugPrint('[Controller] _setLoading çağrıldı: $value'); // EKSTRA LOG
    onStateUpdate(() {});
  }

  void dispose() {
    debugPrint('NewOrderController disposed.');
  }
}
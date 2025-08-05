// lib/controllers/create_order_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/menu_item.dart';
import '../services/order_screen_service.dart';
import '../services/order_service.dart';
import '../utils/notifiers.dart';
import '../main.dart';

class CreateOrderController {
  final Function(VoidCallback fn) onStateUpdate;
  final Function(String message, {bool isError}) showSnackBarCallback;
  final Function(Widget dialogContent) showDialogCallback;
  final Function(Widget modalContent) showModalBottomSheetCallback;
  final Function(Widget screen) navigateToScreenCallback;
  final Function(bool success) popScreenCallback;
  final Function() popUntilFirstCallback;

  List<dynamic> tables = [];
  List<dynamic> pendingOrders = [];
  List<MenuItem> menuItems = [];
  bool isLoading = true;
  String errorMessage = '';
  int waitingCount = 0;

  final String token;
  final int businessId;
  final AppLocalizations l10n; // YENİ: l10n nesnesi eklendi

  CreateOrderController({
    required this.token,
    required this.businessId,
    required this.onStateUpdate,
    required this.showSnackBarCallback,
    required this.showDialogCallback,
    required this.showModalBottomSheetCallback,
    required this.navigateToScreenCallback,
    required this.popScreenCallback,
    required this.popUntilFirstCallback,
    required this.l10n, // YENİ: Constructor'a eklendi
  }) {
    shouldRefreshWaitingCountNotifier.addListener(_handleWaitingCountRefreshRequest);
  }

  Future<void> refreshData() async {
    _setLoading(true);
    final result = await OrderScreenService.fetchInitialData(token, businessId);

    if (result['success']) {
      tables = result['tables'];
      pendingOrders = result['pendingOrders'];
      if (result['menuItems'] is List<MenuItem>) {
        menuItems = result['menuItems'];
      } else {
        menuItems = [];
        debugPrint("Warning: menuItems from fetchInitialData is not List<MenuItem>");
      }
      waitingCount = result['waitingCount'];
      errorMessage = '';
    } else {
      errorMessage = result['errorMessage'] ?? l10n.unknownErrorOccurred;
      tables = [];
      pendingOrders = [];
      menuItems = [];
      waitingCount = 0;
    }
    _setLoading(false);
  }

  Future<void> refreshOrdersAndWaitingCount() async {
    final ordersResult = await OrderService.fetchPendingOrdersOnly(token, businessId);
    final countResult = await OrderService.fetchWaitingCountOnly(token);

    bool stateChanged = false;
    if (ordersResult != null) {
      pendingOrders = ordersResult;
      stateChanged = true;
    }
    if (countResult != null && waitingCount != countResult) {
      waitingCount = countResult;
      stateChanged = true;
    }
    if (stateChanged) {
      onStateUpdate(() {});
    }
  }

  Future<void> refreshWaitingCount() async {
    final count = await OrderService.fetchWaitingCountOnly(token);
    bool countChanged = false;
    if (count != null && count != waitingCount) {
      waitingCount = count;
      countChanged = true;
    }
    if (countChanged) {
      onStateUpdate(() {});
    }
  }

  void _handleWaitingCountRefreshRequest() {
    if (shouldRefreshWaitingCountNotifier.value) {
      debugPrint("CreateOrderController: shouldRefreshWaitingCountNotifier tetiklendi, sayaç yenileniyor.");
      refreshWaitingCount().then((_) {
        if (shouldRefreshWaitingCountNotifier.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(shouldRefreshWaitingCountNotifier.value) {
                shouldRefreshWaitingCountNotifier.value = false;
            }
          });
        }
      });
    }
  }

  void openWaitingCustomersModal(Widget modalContent) {
    showModalBottomSheetCallback(modalContent);
  }

  Future<void> handleTransferOrder(int orderId, int newTableId) async {
    showSnackBarCallback(l10n.infoTransferringTable, isError: false);
    try {
      final resp = await OrderScreenService.transferOrder(token, orderId, newTableId);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        showSnackBarCallback(l10n.infoTransferSuccess, isError: false);
        await refreshData();
      } else {
        showSnackBarCallback(l10n.errorTransferringTable(resp.statusCode.toString(), utf8.decode(resp.bodyBytes)), isError: true);
      }
    } catch (e) {
      showSnackBarCallback(l10n.errorTransferGeneric(e.toString()), isError: true);
    }
  }

  Future<void> handleCancelOrder(int orderId) async {
    showSnackBarCallback(l10n.infoCancellingOrder, isError: false);
    try {
      final resp = await OrderService.cancelOrder(token, orderId);
      if (resp.statusCode == 204 || resp.statusCode == 200) {
        showSnackBarCallback(l10n.infoOrderCancelled, isError: false);
        await refreshData();
      } else {
        String errorMessageDetail = l10n.errorUnknownServer;
        try {
          final decodedBody = jsonDecode(utf8.decode(resp.bodyBytes));
          if (decodedBody is Map && decodedBody.containsKey('detail')) {
              errorMessageDetail = decodedBody['detail'];
          } else {
              errorMessageDetail = utf8.decode(resp.bodyBytes);
          }
        } catch (_) {
            errorMessageDetail = utf8.decode(resp.bodyBytes).isNotEmpty ? utf8.decode(resp.bodyBytes) : l10n.errorDuringCancellation;
        }
        showSnackBarCallback(l10n.errorCancellingOrderWithDetails(resp.statusCode.toString(), errorMessageDetail), isError: true);
      }
    } catch (e) {
      showSnackBarCallback(l10n.errorCancellationGeneric(e.toString()), isError: true);
    }
  }

  Future<void> handleApproveGuestOrder(int orderId) async {
    _setLoading(true);
    showSnackBarCallback(l10n.infoApprovingOrder, isError: false);
    try {
      final resp = await OrderService.approveGuestOrder(token: token, orderId: orderId);
      if (resp.statusCode == 200) {
        showSnackBarCallback(l10n.infoGuestOrderApproved, isError: false);
        await refreshData();
      } else {
        String errorDetail = utf8.decode(resp.bodyBytes);
        try {
          final decoded = jsonDecode(errorDetail);
          if(decoded is Map && decoded.containsKey('detail')) {
            errorDetail = decoded['detail'];
          }
        } catch (_) {}
        showSnackBarCallback(l10n.errorApprovingOrder(resp.statusCode.toString(), errorDetail), isError: true);
      }
    } catch (e) {
      showSnackBarCallback(l10n.errorApprovalGeneric(e.toString()), isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> handleRejectGuestOrder(int orderId) async {
    _setLoading(true);
    showSnackBarCallback(l10n.infoRejectingOrder, isError: false);
    try {
      final resp = await OrderService.rejectGuestOrder(token: token, orderId: orderId);
      if (resp.statusCode == 200) {
        showSnackBarCallback(l10n.infoGuestOrderRejected, isError: false);
        await refreshData();
      } else {
         String errorDetail = utf8.decode(resp.bodyBytes);
        try {
          final decoded = jsonDecode(errorDetail);
          if(decoded is Map && decoded.containsKey('detail')) {
            errorDetail = decoded['detail'];
          }
        } catch (_) {}
        showSnackBarCallback(l10n.errorRejectingOrder(resp.statusCode.toString(), errorDetail), isError: true);
      }
    } catch (e) {
      showSnackBarCallback(l10n.errorRejectionGeneric(e.toString()), isError: true);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (isLoading == value) return;
    isLoading = value;
    onStateUpdate(() {});
  }

  void dispose() {
    shouldRefreshWaitingCountNotifier.removeListener(_handleWaitingCountRefreshRequest);
    debugPrint('CreateOrderController dispose called.');
  }
}
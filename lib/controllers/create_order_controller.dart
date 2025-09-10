// lib/controllers/create_order_controller.dart

import 'dart:async';
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
  final AppLocalizations l10n;

  // 🔥 YENİ: Enhanced refresh management
  Timer? _refreshRetryTimer;
  int _refreshAttempts = 0;
  bool _isRefreshing = false;
  
  static const int MAX_REFRESH_ATTEMPTS = 5;
  static const int REFRESH_RETRY_INTERVAL_BASE = 2; // seconds

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
    required this.l10n,
  }) {
    shouldRefreshWaitingCountNotifier.addListener(_handleWaitingCountRefreshRequest);
  }

  // 🔥 ÇÖZÜM 1: Enhanced refresh with multiple strategies and retry mechanism
  Future<void> refreshData({bool isForced = false, int maxAttempts = 3}) async {
    debugPrint("🔄 [CONTROLLER] Starting enhanced refresh - forced: $isForced, attempts: $maxAttempts");
    
    // Prevent multiple simultaneous refreshes
    if (_isRefreshing && !isForced) {
      debugPrint("🔄 [CONTROLLER] Refresh already in progress, skipping...");
      return;
    }
    
    _isRefreshing = true;
    
    if (isForced) {
      // 🔥 Force immediate UI update for responsiveness
      onStateUpdate(() {});
    }
    
    _setLoading(true);
    
    int attempt = 0;
    bool success = false;
    
    while (attempt < maxAttempts && !success) {
      attempt++;
      debugPrint("🔄 [CONTROLLER] Refresh attempt $attempt/$maxAttempts");
      
      try {
        // 🔥 Progressive timeout: starts at 10s, increases by 5s each attempt
        final timeoutDuration = Duration(seconds: 10 + (attempt * 5));
        
        final result = await OrderScreenService.fetchInitialData(token, businessId)
          .timeout(
            timeoutDuration,
            onTimeout: () {
              debugPrint("🔄 [CONTROLLER] Refresh timeout on attempt $attempt (${timeoutDuration.inSeconds}s)");
              throw TimeoutException('Refresh timeout', timeoutDuration);
            },
          );

        if (result['success']) {
          // 🔥 Update all data
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
          success = true;
          
          debugPrint("🔄 [CONTROLLER] Refresh successful on attempt $attempt");
          
        } else {
          errorMessage = result['errorMessage'] ?? l10n.unknownErrorOccurred;
          debugPrint("🔄 [CONTROLLER] Refresh failed with error: $errorMessage");
          
          if (attempt == maxAttempts) {
            // 🔥 Last attempt failed, but still clear loading and keep existing data
            tables = tables; // Keep existing data instead of clearing
            pendingOrders = pendingOrders;
            menuItems = menuItems;
            waitingCount = waitingCount;
          }
        }
        
      } catch (e) {
        debugPrint("🔄 [CONTROLLER] Refresh exception on attempt $attempt: $e");
        
        if (attempt == maxAttempts) {
          // 🔥 Final attempt, set error state but preserve existing data if possible
          if (tables.isEmpty && pendingOrders.isEmpty && menuItems.isEmpty) {
            errorMessage = e.toString();
            tables = [];
            pendingOrders = [];
            menuItems = [];
            waitingCount = 0;
          } else {
            // Keep existing data and just log the error
            errorMessage = '';
            debugPrint("🔄 [CONTROLLER] Keeping existing data after final attempt failure");
          }
        } else {
          // 🔥 Wait before retry with exponential backoff
          await Future.delayed(Duration(seconds: attempt * REFRESH_RETRY_INTERVAL_BASE));
        }
      }
    }
    
    _setLoading(false);
    _isRefreshing = false;
    
    // 🔥 ÇÖZÜM 2: Trigger additional refresh after delay for safety
    if (success) {
      _scheduleFollowUpRefresh();
    }
    
    // 🔥 Force UI update
    onStateUpdate(() {});
  }

  // 🔥 ÇÖZÜM 3: Follow-up refresh for extra reliability
  void _scheduleFollowUpRefresh() {
    Timer(const Duration(seconds: 3), () {
      if (!isLoading && !_isRefreshing) {
        debugPrint("🔄 [CONTROLLER] Safety follow-up refresh triggered");
        refreshOrdersAndWaitingCount(maxAttempts: 2);
      }
    });
  }

  // 🔥 ÇÖZÜM 4: Enhanced order refresh with retry mechanism
  Future<void> refreshOrdersAndWaitingCount({int maxAttempts = 3}) async {
    debugPrint("🔄 [CONTROLLER] Refreshing orders and waiting count with $maxAttempts attempts");
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final timeoutDuration = Duration(seconds: 8 + (attempt * 2));
        
        final results = await Future.wait([
          OrderService.fetchPendingOrdersOnly(token, businessId),
          OrderService.fetchWaitingCountOnly(token),
        ]).timeout(
          timeoutDuration,
          onTimeout: () {
            debugPrint("🔄 [CONTROLLER] Orders refresh timeout on attempt $attempt (${timeoutDuration.inSeconds}s)");
            throw TimeoutException('Orders refresh timeout', timeoutDuration);
          },
        );

        bool stateChanged = false;
        
        if (results[0] != null) {
          pendingOrders = results[0] as List<dynamic>;
          stateChanged = true;
          debugPrint("🔄 [CONTROLLER] Pending orders updated: ${pendingOrders.length} orders");
        }
        
        if (results[1] != null && waitingCount != results[1]) {
          waitingCount = results[1] as int;
          stateChanged = true;
          debugPrint("🔄 [CONTROLLER] Waiting count updated: $waitingCount");
        }
        
        if (stateChanged) {
          onStateUpdate(() {});
          debugPrint("🔄 [CONTROLLER] Orders refresh successful on attempt $attempt");
          break; // Success, exit loop
        }
        
      } catch (e) {
        debugPrint("🔄 [CONTROLLER] Orders refresh error on attempt $attempt: $e");
        
        if (attempt == maxAttempts) {
          // 🔥 Force UI update even on final failure
          onStateUpdate(() {});
          debugPrint("🔄 [CONTROLLER] Orders refresh completed with errors after $maxAttempts attempts");
        } else {
          // Wait before retry
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
  }

  // 🔥 ÇÖZÜM 5: Enhanced waiting count refresh with immediate callback
  Future<void> refreshWaitingCount({bool immediate = false}) async {
    debugPrint("🔄 [CONTROLLER] Refreshing waiting count - immediate: $immediate");
    
    try {
      final count = await OrderService.fetchWaitingCountOnly(token)
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            debugPrint("🔄 [CONTROLLER] Waiting count timeout");
            throw TimeoutException('Waiting count timeout', const Duration(seconds: 8));
          },
        );
        
      bool countChanged = false;
      if (count != null && count != waitingCount) {
        waitingCount = count;
        countChanged = true;
        debugPrint("🔄 [CONTROLLER] Waiting count changed to: $waitingCount");
      }
      
      if (countChanged || immediate) {
        onStateUpdate(() {});
      }
    } catch (e) {
      debugPrint("🔄 [CONTROLLER] Waiting count refresh error: $e");
      // Don't fail silently - still trigger UI update for immediate requests
      if (immediate) {
        onStateUpdate(() {});
      }
    }
  }

  void _handleWaitingCountRefreshRequest() {
    if (shouldRefreshWaitingCountNotifier.value) {
      debugPrint("CreateOrderController: shouldRefreshWaitingCountNotifier tetiklendi, sayaç yenileniyor.");
      
      // 🔥 Use enhanced refresh with immediate flag
      refreshWaitingCount(immediate: true).then((_) {
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

  // 🔥 ÇÖZÜM 6: Enhanced transfer with immediate refresh
  Future<void> handleTransferOrder(int orderId, int newTableId) async {
    showSnackBarCallback(l10n.infoTransferringTable, isError: false);
    try {
      final resp = await OrderScreenService.transferOrder(token, orderId, newTableId);
      
      // 🔥 Always refresh regardless of response
      await refreshData(isForced: true, maxAttempts: 2);
      
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        showSnackBarCallback(l10n.infoTransferSuccess, isError: false);
        debugPrint("🔄 [TRANSFER] Transfer successful, data refreshed");
      } else {
        showSnackBarCallback(l10n.errorTransferringTable(resp.statusCode.toString(), utf8.decode(resp.bodyBytes)), isError: true);
        debugPrint("🔄 [TRANSFER] Transfer failed but data refreshed");
      }
    } catch (e) {
      // 🔥 Even on exception, try to refresh
      try {
        await refreshData(isForced: true, maxAttempts: 1);
      } catch (refreshError) {
        debugPrint("🔄 [TRANSFER] Exception recovery refresh failed: $refreshError");
      }
      
      showSnackBarCallback(l10n.errorTransferGeneric(e.toString()), isError: true);
    }
  }

  // 🔥 ÇÖZÜM 7: Enhanced cancel order with guaranteed refresh
  Future<void> handleCancelOrder(int orderId) async {
    debugPrint("🔄 [CANCEL] Cancel order started for ID: $orderId");
    
    showSnackBarCallback(l10n.infoCancellingOrder, isError: false);
    
    try {
      final resp = await OrderService.cancelOrder(token, orderId);
      debugPrint("🔄 [CANCEL] Cancel response: ${resp.statusCode}");
      
      // 🔥 ALWAYS refresh data regardless of response status
      await refreshData(isForced: true, maxAttempts: 3);
      debugPrint("🔄 [CANCEL] Refresh data completed");
      
      if (resp.statusCode == 204 || resp.statusCode == 200) {
        showSnackBarCallback(l10n.infoOrderCancelled, isError: false);
        debugPrint("🔄 [CANCEL] Order cancelled successfully");
        
        // 🔥 Multiple UI update triggers for reliability
        onStateUpdate(() {});
        
        // 🔥 Notification system trigger
        WidgetsBinding.instance.addPostFrameCallback((_) {
          shouldRefreshTablesNotifier.value = !shouldRefreshTablesNotifier.value;
        });
        
        // 🔥 Additional safety refresh
        Timer(const Duration(milliseconds: 1000), () {
          refreshOrdersAndWaitingCount(maxAttempts: 2);
        });
        
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
        debugPrint("🔄 [CANCEL] Cancel failed but refresh completed");
      }
    } catch (e) {
      debugPrint("🔄 [CANCEL] Cancel order error: $e");
      
      // 🔥 Exception durumunda da guaranteed refresh
      try {
        await refreshData(isForced: true, maxAttempts: 2);
        debugPrint("🔄 [CANCEL] Exception recovery refresh completed");
      } catch (refreshError) {
        debugPrint("🔄 [CANCEL] Even recovery refresh failed: $refreshError");
      }
      
      showSnackBarCallback(l10n.errorCancellationGeneric(e.toString()), isError: true);
    }
    
    // 🔥 Final guaranteed safety refresh with delay
    Timer(const Duration(milliseconds: 1500), () async {
      try {
        await refreshOrdersAndWaitingCount(maxAttempts: 2);
        debugPrint("🔄 [CANCEL] Final safety refresh completed");
      } catch (e) {
        debugPrint("🔄 [CANCEL] Final safety refresh failed: $e");
      }
    });
  }

  // 🔥 ÇÖZÜM 8: Enhanced approve with guaranteed refresh
  Future<void> handleApproveGuestOrder(int orderId) async {
    _setLoading(true);
    showSnackBarCallback(l10n.infoApprovingOrder, isError: false);
    try {
      final resp = await OrderService.approveGuestOrder(token: token, orderId: orderId);
      
      // 🔥 Always refresh
      await refreshData(isForced: true, maxAttempts: 2);
      
      if (resp.statusCode == 200) {
        showSnackBarCallback(l10n.infoGuestOrderApproved, isError: false);
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
      // 🔥 Exception recovery refresh
      try {
        await refreshData(isForced: true, maxAttempts: 1);
      } catch (refreshError) {
        debugPrint("🔄 [APPROVE] Exception recovery refresh failed: $refreshError");
      }
      
      showSnackBarCallback(l10n.errorApprovalGeneric(e.toString()), isError: true);
    } finally {
      _setLoading(false);
    }
  }

  // 🔥 ÇÖZÜM 9: Enhanced reject with guaranteed refresh
  Future<void> handleRejectGuestOrder(int orderId) async {
    _setLoading(true);
    showSnackBarCallback(l10n.infoRejectingOrder, isError: false);
    try {
      final resp = await OrderService.rejectGuestOrder(token: token, orderId: orderId);
      
      // 🔥 Always refresh
      await refreshData(isForced: true, maxAttempts: 2);
      
      if (resp.statusCode == 200) {
        showSnackBarCallback(l10n.infoGuestOrderRejected, isError: false);
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
      // 🔥 Exception recovery refresh
      try {
        await refreshData(isForced: true, maxAttempts: 1);
      } catch (refreshError) {
        debugPrint("🔄 [REJECT] Exception recovery refresh failed: $refreshError");
      }
      
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
    _refreshRetryTimer?.cancel();
    shouldRefreshWaitingCountNotifier.removeListener(_handleWaitingCountRefreshRequest);
    debugPrint('CreateOrderController dispose called.');
  }
}
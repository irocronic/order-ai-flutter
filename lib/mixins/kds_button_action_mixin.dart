// lib/mixins/kds_button_action_mixin.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/kds_service.dart';

mixin KdsButtonActionMixin<T extends StatefulWidget> on State<T> {
  // 🔥 Enhanced action management
  final Map<String, Completer<bool>?> _activeRequests = {};
  final Map<String, Timer?> _debounceTimers = {};
  final Map<String, String> _optimisticStates = {};
  final Map<String, int> _retryCounters = {};
  final Map<String, DateTime> _lastActionTime = {};
  
  // Action processing states
  final Map<String, bool> _actionProcessingStates = {};
  
  // Constants
  static const int DEBOUNCE_DELAY_MS = 800;
  static const int MAX_RETRY_COUNT = 2;
  static const int REQUEST_TIMEOUT_SECONDS = 15;
  
  // Required getters - must be implemented by the using class
  String get token;
  bool get isDisposed;
  bool get mounted;
  
  // Required methods - must be implemented by the using class
  void onActionSuccess(String actionType, dynamic result);
  void onActionError(String actionType, String error);
  void showLoadingFeedback(String message);
  void showSuccessFeedback(String message);
  void showErrorFeedback(String message);

  // 🔥 Enhanced button state checker
  bool canPerformAction(String actionKey) {
    // Active request check
    if (_activeRequests.containsKey(actionKey) && 
        _activeRequests[actionKey] != null && 
        !_activeRequests[actionKey]!.isCompleted) {
      return false;
    }
    
    // Processing state check
    if (_actionProcessingStates[actionKey] == true) {
      return false;
    }
    
    // Debounce timer check
    if (_debounceTimers[actionKey]?.isActive == true) {
      return false;
    }
    
    // Spam prevention check
    final lastAction = _lastActionTime[actionKey];
    if (lastAction != null && DateTime.now().difference(lastAction).inSeconds < 2) {
      return false;
    }
    
    return true;
  }

  // 🔥 Main action handler
  Future<void> handleKdsAction({
    required String actionKey,
    required String actionType,
    required Map<String, dynamic> parameters,
    required String loadingMessage,
    required String successMessage,
  }) async {
    if (!mounted || isDisposed) return;
    
    // Check if action can be performed
    if (!canPerformAction(actionKey)) {
      debugPrint("🔄 [KDS-ACTION] Action $actionKey blocked - conditions not met");
      return;
    }
    
    // Cancel any existing request
    if (_activeRequests[actionKey] != null && !_activeRequests[actionKey]!.isCompleted) {
      debugPrint("🔄 [KDS-ACTION] Cancelling existing request for $actionKey");
      _activeRequests[actionKey]?.complete(false);
    }
    
    // Cancel debounce timer
    _debounceTimers[actionKey]?.cancel();
    
    // Set optimistic state
    if (mounted) {
      setState(() {
        _actionProcessingStates[actionKey] = true;
        _optimisticStates[actionKey] = actionType;
      });
    }
    
    showLoadingFeedback(loadingMessage);
    
    // Debounced execution
    _debounceTimers[actionKey] = Timer(Duration(milliseconds: DEBOUNCE_DELAY_MS), () {
      if (mounted && !isDisposed) {
        _executeActionWithRetry(actionKey, actionType, parameters, successMessage);
      }
    });
  }

  // 🔥 Execute action with retry mechanism
  Future<void> _executeActionWithRetry(
    String actionKey,
    String actionType,
    Map<String, dynamic> parameters,
    String successMessage,
  ) async {
    if (!mounted || isDisposed) return;
    
    final completer = Completer<bool>();
    _activeRequests[actionKey] = completer;
    _retryCounters[actionKey] = 0;
    _lastActionTime[actionKey] = DateTime.now();
    
    try {
      final success = await _performActionWithRetry(actionKey, actionType, parameters);
      
      if (mounted && !isDisposed) {
        if (success) {
          showSuccessFeedback(successMessage);
          _optimisticStates.remove(actionKey);
          onActionSuccess(actionType, null);
        } else {
          _rollbackOptimisticUpdate(actionKey);
          showErrorFeedback("$actionType işlemi başarısız oldu");
          onActionError(actionType, "İşlem başarısız");
        }
      }
      
      completer.complete(success);
      
    } catch (e) {
      debugPrint("🔄 [KDS-ACTION] Critical error for $actionKey: $e");
      if (mounted && !isDisposed) {
        _rollbackOptimisticUpdate(actionKey);
        showErrorFeedback("Beklenmeyen hata: $e");
        onActionError(actionType, e.toString());
      }
      completer.complete(false);
      
    } finally {
      if (mounted && !isDisposed) {
        setState(() {
          _actionProcessingStates[actionKey] = false;
        });
        _activeRequests.remove(actionKey);
      }
    }
  }

  // 🔥 Retry mechanism
  Future<bool> _performActionWithRetry(
    String actionKey,
    String actionType,
    Map<String, dynamic> parameters,
  ) async {
    int currentRetry = _retryCounters[actionKey] ?? 0;
    
    while (currentRetry <= MAX_RETRY_COUNT) {
      try {
        debugPrint("🔄 [KDS-ACTION] Attempt ${currentRetry + 1}/${MAX_RETRY_COUNT + 1} for $actionKey");
        
        final response = await _performKdsApiCall(actionType, parameters).timeout(
          const Duration(seconds: REQUEST_TIMEOUT_SECONDS),
          onTimeout: () => throw TimeoutException('Request timeout', const Duration(seconds: REQUEST_TIMEOUT_SECONDS)),
        );
        
        if (response['success'] == true) {
          debugPrint("🔄 [KDS-ACTION] Success on attempt ${currentRetry + 1} for $actionKey");
          return true;
        } else if (response['statusCode'] == 409 || response['statusCode'] == 400) {
          debugPrint("🔄 [KDS-ACTION] Business error ${response['statusCode']} for $actionKey, not retrying");
          return false;
        } else {
          throw Exception("API Error: ${response['message'] ?? 'Unknown error'}");
        }
        
      } catch (e) {
        currentRetry++;
        _retryCounters[actionKey] = currentRetry;
        
        if (currentRetry <= MAX_RETRY_COUNT) {
          debugPrint("🔄 [KDS-ACTION] Retry $currentRetry for $actionKey after error: $e");
          await Future.delayed(Duration(seconds: currentRetry * 2)); // Exponential backoff
        } else {
          debugPrint("🔄 [KDS-ACTION] Max retries reached for $actionKey");
          throw e;
        }
      }
    }
    
    return false;
  }

  // 🔥 API call dispatcher
  Future<Map<String, dynamic>> _performKdsApiCall(
    String actionType,
    Map<String, dynamic> parameters,
  ) async {
    try {
      dynamic response;
      
      switch (actionType) {
        case 'mark_preparing':
          response = await KdsService.startPreparingItem(
            token,
            parameters['orderItemId'],
          );
          break;
        case 'mark_ready':
          response = await KdsService.markItemReady(
            token,
            parameters['orderItemId'],
          );
          break;
        case 'start_preparation':
          response = await KdsService.startPreparation(
            token,
            parameters['kdsScreenSlug'],
            parameters['orderId'],
          );
          break;
        case 'mark_order_ready':
          response = await KdsService.markOrderReady(
            token,
            parameters['kdsScreenSlug'],
            parameters['orderId'],
          );
          break;
        case 'refresh_orders':
          // Special case for refresh - always successful
          return {'success': true, 'data': 'refresh'};
        default:
          throw Exception('Unknown action type: $actionType');
      }
      
      if (response != null && response.statusCode == 200) {
        return {'success': true, 'data': response.body};
      } else {
        return {
          'success': false,
          'statusCode': response?.statusCode ?? 0,
          'message': response?.body ?? 'Unknown error'
        };
      }
      
    } catch (e) {
      return {
        'success': false,
        'statusCode': 0,
        'message': e.toString()
      };
    }
  }

  // 🔥 Rollback optimistic update
  void _rollbackOptimisticUpdate(String actionKey) {
    if (mounted && !isDisposed) {
      setState(() {
        _optimisticStates.remove(actionKey);
      });
    }
  }

  // 🔥 Check if action is processing
  bool isActionProcessing(String actionKey) {
    return _actionProcessingStates[actionKey] ?? false;
  }

  // 🔥 Get optimistic state
  String? getOptimisticState(String actionKey) {
    return _optimisticStates[actionKey];
  }

  // 🔥 Enhanced loading indicator
  Widget buildEnhancedLoadingIndicator({
    required Color color,
    required String message,
    double size = 28,
  }) {
    return Tooltip(
      message: message,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            Center(
              child: Icon(
                Icons.more_horiz,
                size: size * 0.4,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 Cleanup method
  void disposeKdsButtonActionMixin() {
    // Cancel all active requests
    for (var completer in _activeRequests.values) {
      if (completer != null && !completer.isCompleted) {
        completer.complete(false);
      }
    }
    
    // Cancel all timers
    for (var timer in _debounceTimers.values) {
      timer?.cancel();
    }
    
    // Clear all maps
    _activeRequests.clear();
    _debounceTimers.clear();
    _optimisticStates.clear();
    _retryCounters.clear();
    _lastActionTime.clear();
    _actionProcessingStates.clear();
  }
}
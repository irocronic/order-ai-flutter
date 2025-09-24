// lib/widgets/table_cell_widget.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/order_service.dart';
import '../services/notification_center.dart';
import '../models/menu_item.dart';
import '../utils/localization_helper.dart';

class TableCellWidget extends StatefulWidget {
  final dynamic table;
  final bool isOccupied;
  final dynamic pendingOrder;
  final String token;
  final List<MenuItem> allMenuItems;
  final VoidCallback onTap;
  final VoidCallback onTransfer;
  final VoidCallback onCancel;
  final VoidCallback onOrderUpdated;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onAddItem;

  const TableCellWidget({
    Key? key,
    required this.table,
    required this.isOccupied,
    this.pendingOrder,
    required this.token,
    required this.allMenuItems,
    required this.onTap,
    required this.onTransfer,
    required this.onCancel,
    required this.onOrderUpdated,
    required this.onApprove,
    required this.onReject,
    required this.onAddItem,
  }) : super(key: key);

  @override
  _TableCellWidgetState createState() => _TableCellWidgetState();
}

class _TableCellWidgetState extends State<TableCellWidget> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isProcessingAction = false;

  // 🔥 YENİ: Smart refresh management
  final Map<int, bool> _itemProcessingStates = {};
  final Map<int, DateTime> _lastActionTime = {};
  
  // 🔥 YENİ: Anti-flickering system
  Timer? _refreshCooldownTimer;
  DateTime? _lastRefreshTime;
  bool _isInRefreshCooldown = false;
  int _pendingRefreshCount = 0;

  // 🔥 YENİ: Enhanced action management
  final Map<int, Completer<bool>?> _activeRequests = {};
  final Map<int, Timer?> _debounceTimers = {};
  final Map<int, String> _optimisticStates = {};
  final Map<int, int> _retryCounters = {};
  
  // 🔥 YENİ: Action completion tracking
  final Map<int, bool> _completedRequests = {}; // Track completed requests
  
  // Constants
  static const int REFRESH_COOLDOWN_MS = 1500;
  static const int MAX_PENDING_REFRESHES = 3;
  static const int OPERATION_TIMEOUT_SECONDS = 15;
  static const int DEBOUNCE_DELAY_MS = 800;
  static const int MAX_RETRY_COUNT = 2;

  // NotificationCenter callbacks
  late Function(Map<String, dynamic>) _kdsUpdateCallback;
  late Function(Map<String, dynamic>) _screenActiveCallback;

  // Status constants (unchanged)
  static const String STATUS_PENDING_APPROVAL = 'pending_approval';
  static const String STATUS_PENDING_SYNC = 'pending_sync';
  static const String STATUS_APPROVED = 'approved';
  static const String STATUS_PREPARING = 'preparing';
  static const String STATUS_READY_FOR_PICKUP = 'ready_for_pickup';
  static const String STATUS_READY_FOR_DELIVERY = 'ready_for_delivery';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_CANCELLED = 'cancelled';
  static const String STATUS_REJECTED = 'rejected';

  static const String KDS_ITEM_STATUS_PENDING = 'pending_kds';
  static const String KDS_ITEM_STATUS_PREPARING = 'preparing_kds';
  static const String KDS_ITEM_STATUS_READY = 'ready_kds';
  static const String KDS_ITEM_STATUS_PICKED_UP = 'picked_up_kds';

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
    _setupNotificationListeners();
  }

  @override
  void didUpdateWidget(covariant TableCellWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingOrder != oldWidget.pendingOrder) {
      _timer?.cancel();
      _startTimerIfNeeded();
      // Clear all processing states for new order
      _itemProcessingStates.clear();
      _lastActionTime.clear();
      _optimisticStates.clear();
      _retryCounters.clear();
      _completedRequests.clear(); // 🔥 Clear completion tracking
      
      // Cancel any active requests and timers
      _cleanupActiveRequests();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshCooldownTimer?.cancel();
    
    // 🔥 Enhanced cleanup
    _cleanupActiveRequests();
    _cleanupDebounceTimers();
    _cleanupNotificationListeners();
    
    super.dispose();
  }

  // 🔥 FIXED: Enhanced cleanup methods with completion tracking
  void _cleanupActiveRequests() {
    for (var entry in _activeRequests.entries) {
      final itemId = entry.key;
      final completer = entry.value;
      
      if (completer != null && !completer.isCompleted && !(_completedRequests[itemId] ?? false)) {
        completer.complete(false);
        _completedRequests[itemId] = true;
      }
    }
    _activeRequests.clear();
    _completedRequests.clear();
  }

  void _cleanupDebounceTimers() {
    for (var timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
  }

  void _setupNotificationListeners() {
    _kdsUpdateCallback = (data) {
      if (!mounted) return;
      
      final eventType = data['event_type'] as String?;
      final orderId = data['order_id'];
      
      if (widget.pendingOrder != null && 
          orderId != null && 
          (widget.pendingOrder['id'] == orderId || 
           widget.pendingOrder['temp_id'] == orderId.toString())) {
        
        debugPrint('[TableCellWidget] 🔥 KDS update for order #$orderId: $eventType');
        
        _smartRefresh(source: 'kds_notification');
        _showKdsUpdateFeedback(eventType);
      }
    };

    _screenActiveCallback = (data) {
      if (!mounted) return;
      debugPrint('[TableCellWidget] 📱 Screen became active');
      _startTimerIfNeeded();
    };

    NotificationCenter.instance.addObserver('kds_priority_update', _kdsUpdateCallback);
    NotificationCenter.instance.addObserver('screen_became_active', _screenActiveCallback);
    
    debugPrint('[TableCellWidget] 🎯 Listeners registered for table ${widget.table['table_number']}');
  }

  void _cleanupNotificationListeners() {
    NotificationCenter.instance.removeObserver('kds_priority_update', _kdsUpdateCallback);
    NotificationCenter.instance.removeObserver('screen_became_active', _screenActiveCallback);
    
    debugPrint('[TableCellWidget] 🗑️ Listeners cleaned up for table ${widget.table['table_number']}');
  }

  // Smart refresh with anti-flickering (unchanged)
  void _smartRefresh({required String source}) {
    final now = DateTime.now();
    
    if (_isInRefreshCooldown) {
      _pendingRefreshCount++;
      debugPrint("🔄 [SMART] Refresh cooldown active, pending count: $_pendingRefreshCount (source: $source)");
      
      if (_pendingRefreshCount > MAX_PENDING_REFRESHES) {
        debugPrint("🔄 [SMART] Max pending refreshes reached, skipping");
        return;
      }
      
      _scheduleRefreshAfterCooldown();
      return;
    }
    
    debugPrint("🔄 [SMART] Executing immediate refresh (source: $source)");
    _executeRefresh();
    
    _startRefreshCooldown();
  }

  void _executeRefresh() {
    if (!mounted) return;
    
    try {
      widget.onOrderUpdated();
      _lastRefreshTime = DateTime.now();
      debugPrint("🔄 [SMART] Refresh executed successfully");
    } catch (e) {
      debugPrint("🔄 [SMART] Refresh error: $e");
    }
  }

  void _startRefreshCooldown() {
    _isInRefreshCooldown = true;
    _pendingRefreshCount = 0;
    
    _refreshCooldownTimer?.cancel();
    _refreshCooldownTimer = Timer(Duration(milliseconds: REFRESH_COOLDOWN_MS), () {
      if (mounted) {
        _isInRefreshCooldown = false;
        
        if (_pendingRefreshCount > 0) {
          debugPrint("🔄 [SMART] Cooldown ended, executing pending refresh");
          _executeRefresh();
          _startRefreshCooldown();
        } else {
          debugPrint("🔄 [SMART] Cooldown ended, no pending refreshes");
        }
      }
    });
  }

  void _scheduleRefreshAfterCooldown() {
    // This method ensures a refresh happens after cooldown
  }

  // 🔥 FIXED: Enhanced button state checker with completion tracking
  bool _canPerformAction(int orderItemId) {
    // Check if request is already completed
    if (_completedRequests[orderItemId] == true) {
      return false;
    }
    
    // Active request check
    if (_activeRequests.containsKey(orderItemId) && 
        _activeRequests[orderItemId] != null && 
        !_activeRequests[orderItemId]!.isCompleted) {
      return false;
    }
    
    // Processing state check
    if (_itemProcessingStates[orderItemId] == true) {
      return false;
    }
    
    // Debounce timer check
    if (_debounceTimers[orderItemId]?.isActive == true) {
      return false;
    }
    
    return true;
  }

  // 🔥 FIXED: Safe completer completion
  void _safeCompleteRequest(int orderItemId, bool result) {
    if (_completedRequests[orderItemId] == true) {
      debugPrint("🔄 Request for item $orderItemId already completed, skipping");
      return;
    }
    
    final completer = _activeRequests[orderItemId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
      _completedRequests[orderItemId] = true;
      debugPrint("🔄 Request for item $orderItemId completed with result: $result");
    }
  }

  void _rollbackOptimisticUpdate(int orderItemId) {
    if (!mounted) return;
    setState(() {
      _optimisticStates.remove(orderItemId);
    });
    _smartRefresh(source: 'rollback');
  }

  // 🔥 FIXED: Enhanced item pickup with safe completion
  Future<void> _handleItemPickup(int orderItemId, AppLocalizations l10n) async {
    if (!mounted) return;
    
    // Cancel any existing request safely
    if (_activeRequests[orderItemId] != null && !(_completedRequests[orderItemId] ?? false)) {
      debugPrint("🔄 [PICKUP] Item $orderItemId - Cancelling existing request");
      _safeCompleteRequest(orderItemId, false);
    }
    
    // Clean up before starting new request
    _debounceTimers[orderItemId]?.cancel();
    _completedRequests[orderItemId] = false; // Reset completion tracking
    
    // Optimistic UI update
    if (mounted) {
      setState(() {
        _itemProcessingStates[orderItemId] = true;
        _optimisticStates[orderItemId] = 'picking_up';
      });
    }
    
    _showOverlayFeedback(Colors.purple, Icons.pan_tool_alt, '👐 Teslim alınıyor...');
    
    // Debounced execution
    _debounceTimers[orderItemId] = Timer(Duration(milliseconds: DEBOUNCE_DELAY_MS), () {
      if (mounted && !(_completedRequests[orderItemId] ?? false)) {
        _executePickupAction(orderItemId, l10n);
      }
    });
  }

  Future<void> _executePickupAction(int orderItemId, AppLocalizations l10n) async {
    if (!mounted || (_completedRequests[orderItemId] ?? false)) return;
    
    // Create new request completer
    final completer = Completer<bool>();
    _activeRequests[orderItemId] = completer;
    _retryCounters[orderItemId] = 0;
    
    try {
      final success = await _performPickupWithRetry(orderItemId, l10n);
      
      if (mounted && !(_completedRequests[orderItemId] ?? false)) {
        if (success) {
          _smartRefresh(source: 'pickup_success');
          _showOverlayFeedback(Colors.green, Icons.check_circle, '✅ Teslim alındı');
          _optimisticStates.remove(orderItemId);
        } else {
          _rollbackOptimisticUpdate(orderItemId);
          _showErrorSnackbar("Teslim alma işlemi başarısız oldu");
        }
      }
      
      _safeCompleteRequest(orderItemId, success);
      
    } catch (e) {
      debugPrint("🔄 [PICKUP] Critical error: $e");
      if (mounted && !(_completedRequests[orderItemId] ?? false)) {
        _rollbackOptimisticUpdate(orderItemId);
        _showErrorSnackbar("Beklenmeyen hata: ${e.toString()}");
      }
      _safeCompleteRequest(orderItemId, false);
      
    } finally {
      if (mounted) {
        setState(() {
          _itemProcessingStates[orderItemId] = false;
        });
        _activeRequests.remove(orderItemId);
        // Don't remove from _completedRequests here to prevent double completion
      }
    }
  }

  // 🔥 FIXED: Enhanced delivery with safe completion
  Future<void> _handleDeliverOrderItem(int orderItemId, AppLocalizations l10n) async {
    if (!mounted) return;
    
    // Cancel any existing request safely
    if (_activeRequests[orderItemId] != null && !(_completedRequests[orderItemId] ?? false)) {
      debugPrint("🔄 [DELIVER] Item $orderItemId - Cancelling existing request");
      _safeCompleteRequest(orderItemId, false);
    }
    
    // Clean up before starting new request
    _debounceTimers[orderItemId]?.cancel();
    _completedRequests[orderItemId] = false; // Reset completion tracking
    
    // Optimistic UI update
    if (mounted) {
      setState(() {
        _itemProcessingStates[orderItemId] = true;
        _optimisticStates[orderItemId] = 'delivering';
      });
    }
    
    _showOverlayFeedback(Colors.green, Icons.check_circle, '🎉 Teslim ediliyor...');
    
    // Debounced execution
    _debounceTimers[orderItemId] = Timer(Duration(milliseconds: DEBOUNCE_DELAY_MS), () {
      if (mounted && !(_completedRequests[orderItemId] ?? false)) {
        _executeDeliveryAction(orderItemId, l10n);
      }
    });
  }

  Future<void> _executeDeliveryAction(int orderItemId, AppLocalizations l10n) async {
    if (!mounted || (_completedRequests[orderItemId] ?? false)) return;
    
    final completer = Completer<bool>();
    _activeRequests[orderItemId] = completer;
    _retryCounters[orderItemId] = 0;
    
    try {
      final success = await _performDeliveryWithRetry(orderItemId, l10n);
      
      if (mounted && !(_completedRequests[orderItemId] ?? false)) {
        if (success) {
          _smartRefresh(source: 'delivery_success');
          _showOverlayFeedback(Colors.green, Icons.check_circle, '🎉 Teslim edildi');
          _optimisticStates.remove(orderItemId);
        } else {
          _rollbackOptimisticUpdate(orderItemId);
          _showErrorSnackbar("Teslimat işlemi başarısız oldu");
        }
      }
      
      _safeCompleteRequest(orderItemId, success);
      
    } catch (e) {
      debugPrint("🔄 [DELIVER] Critical error: $e");
      if (mounted && !(_completedRequests[orderItemId] ?? false)) {
        _rollbackOptimisticUpdate(orderItemId);
        _showErrorSnackbar("Beklenmeyen hata: ${e.toString()}");
      }
      _safeCompleteRequest(orderItemId, false);
      
    } finally {
      if (mounted) {
        setState(() {
          _itemProcessingStates[orderItemId] = false;
        });
        _activeRequests.remove(orderItemId);
        // Don't remove from _completedRequests here to prevent double completion
      }
    }
  }

  Future<bool> _performPickupWithRetry(int orderItemId, AppLocalizations l10n) async {
    int currentRetry = _retryCounters[orderItemId] ?? 0;
    
    while (currentRetry <= MAX_RETRY_COUNT && !(_completedRequests[orderItemId] ?? false)) {
      try {
        debugPrint("🔄 [PICKUP] Attempt ${currentRetry + 1}/${MAX_RETRY_COUNT + 1} for item $orderItemId");
        
        final response = await OrderService.markItemPickedUpByWaiter(
          token: widget.token,
          orderItemId: orderItemId,
        ).timeout(
          const Duration(seconds: OPERATION_TIMEOUT_SECONDS),
          onTimeout: () => throw TimeoutException('Request timeout', const Duration(seconds: OPERATION_TIMEOUT_SECONDS)),
        );
        
        if (response.statusCode == 200) {
          debugPrint("🔄 [PICKUP] Success on attempt ${currentRetry + 1}");
          return true;
        } else if (response.statusCode == 409 || response.statusCode == 400) {
          debugPrint("🔄 [PICKUP] Business error ${response.statusCode}, not retrying");
          return false;
        } else {
          throw Exception("HTTP ${response.statusCode}: ${response.body}");
        }
        
      } catch (e) {
        currentRetry++;
        _retryCounters[orderItemId] = currentRetry;
        
        if (currentRetry <= MAX_RETRY_COUNT && !(_completedRequests[orderItemId] ?? false)) {
          debugPrint("🔄 [PICKUP] Retry $currentRetry after error: $e");
          await Future.delayed(Duration(seconds: currentRetry * 2));
        } else {
          debugPrint("🔄 [PICKUP] Max retries reached or request completed");
          throw e;
        }
      }
    }
    
    return false;
  }

  Future<bool> _performDeliveryWithRetry(int orderItemId, AppLocalizations l10n) async {
    int currentRetry = _retryCounters[orderItemId] ?? 0;
    
    while (currentRetry <= MAX_RETRY_COUNT && !(_completedRequests[orderItemId] ?? false)) {
      try {
        debugPrint("🔄 [DELIVER] Attempt ${currentRetry + 1}/${MAX_RETRY_COUNT + 1} for item $orderItemId");
        
        final response = await OrderService.markOrderItemDelivered(
          token: widget.token,
          orderId: widget.pendingOrder['id'],
          orderItemId: orderItemId,
        ).timeout(
          const Duration(seconds: OPERATION_TIMEOUT_SECONDS),
          onTimeout: () => throw TimeoutException('Request timeout', const Duration(seconds: OPERATION_TIMEOUT_SECONDS)),
        );
        
        if (response.statusCode == 200) {
          debugPrint("🔄 [DELIVER] Success on attempt ${currentRetry + 1}");
          return true;
        } else if (response.statusCode == 409 || response.statusCode == 400) {
          debugPrint("🔄 [DELIVER] Business error ${response.statusCode}, not retrying");
          return false;
        } else {
          throw Exception("HTTP ${response.statusCode}: ${response.body}");
        }
        
      } catch (e) {
        currentRetry++;
        _retryCounters[orderItemId] = currentRetry;
        
        if (currentRetry <= MAX_RETRY_COUNT && !(_completedRequests[orderItemId] ?? false)) {
          debugPrint("🔄 [DELIVER] Retry $currentRetry after error: $e");
          await Future.delayed(Duration(seconds: currentRetry * 2));
        } else {
          debugPrint("🔄 [DELIVER] Max retries reached or request completed");
          throw e;
        }
      }
    }
    
    return false;
  }

  void _showKdsUpdateFeedback(String? eventType) {
    if (!mounted || eventType == null) return;
    
    Color feedbackColor;
    IconData feedbackIcon;
    String feedbackMessage;
    
    switch (eventType) {
      case 'order_preparing_update':
        feedbackColor = Colors.orange;
        feedbackIcon = Icons.whatshot;
        feedbackMessage = '🔥 Hazırlanıyor';
        break;
      case 'order_ready_for_pickup_update':
        feedbackColor = Colors.teal;
        feedbackIcon = Icons.restaurant_menu;
        feedbackMessage = '✅ Hazır';
        break;
      case 'order_item_picked_up':
        feedbackColor = Colors.purple;
        feedbackIcon = Icons.pan_tool_alt;
        feedbackMessage = '👐 Alındı';
        break;
      case 'order_fully_delivered':
        feedbackColor = Colors.green;
        feedbackIcon = Icons.check_circle;
        feedbackMessage = '🎉 Tamamlandı';
        break;
      default:
        return;
    }

    _showOverlayFeedback(feedbackColor, feedbackIcon, feedbackMessage);
  }

  void _showOverlayFeedback(Color color, IconData icon, String message) {
    if (!mounted) return;
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.1,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    Timer(const Duration(milliseconds: 1500), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Widget _buildEnhancedLoadingIndicator(Color color, String message) {
    return Tooltip(
      message: message,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            Center(
              child: Icon(
                Icons.more_horiz,
                size: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTimerIfNeeded() {
    final bool isOrderFinalized = widget.pendingOrder != null &&
        [STATUS_COMPLETED, STATUS_CANCELLED, STATUS_REJECTED, STATUS_PENDING_SYNC]
            .contains(widget.pendingOrder!['status']);

    if (widget.isOccupied && !isOrderFinalized && widget.pendingOrder?['created_at'] != null) {
      try {
        DateTime createdAt = DateTime.parse(widget.pendingOrder!['created_at']);
        _timer?.cancel();
        _updateElapsedSeconds(createdAt);
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          _updateElapsedSeconds(createdAt);
        });
      } catch (e) {
        debugPrint("TableCellWidget - Timer start error: $e");
        if (mounted) setState(() => _elapsedSeconds = 0);
      }
    } else {
      _timer?.cancel();
    }
  }

  void _updateElapsedSeconds(DateTime startTime) {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() => _elapsedSeconds = now.difference(startTime).inSeconds);
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent, duration: Duration(seconds: 2)));
  }

  Widget _buildStatusHeader(AppLocalizations l10n) {
    String statusText;
    Color statusColor = Colors.black87;

    if (widget.isOccupied && widget.pendingOrder != null) {
      statusText = getLocalizedOrderStatus(context, widget.pendingOrder!['status']);

      switch(widget.pendingOrder!['status']) {
        case STATUS_PENDING_SYNC: statusColor = Colors.grey.shade800; break;
        case STATUS_PENDING_APPROVAL: statusColor = Colors.purple.shade800; break;
        case STATUS_APPROVED: statusColor = Colors.blue.shade800; break;
        case STATUS_PREPARING: statusColor = Colors.deepOrange.shade700; break;
        case STATUS_READY_FOR_PICKUP: statusColor = Colors.teal.shade600; break;
        case STATUS_READY_FOR_DELIVERY: statusColor = Colors.indigo.shade700; break;
        default: statusColor = Colors.grey.shade800;
      }
    } else {
       statusText = l10n.tableCellDefaultTitle(widget.table['table_number'].toString());
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (widget.isOccupied && widget.pendingOrder != null)
                _buildKdsStatusIndicator(),
              Expanded(
                child: Text(
                  "#${widget.pendingOrder?['temp_id']?.toString().substring(0, 5) ?? widget.pendingOrder?['id'] ?? widget.table['table_number']} - $statusText",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
        Text(
          _formatDuration(_elapsedSeconds),
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: statusColor),
        ),
      ],
    );
  }

  Widget _buildKdsStatusIndicator() {
    if (widget.pendingOrder == null) return const SizedBox.shrink();
    
    final orderItems = widget.pendingOrder['order_items'] as List?;
    if (orderItems == null || orderItems.isEmpty) return const SizedBox.shrink();
    
    bool hasPreparingItems = false;
    bool hasReadyItems = false;
    bool hasPickedUpItems = false;
    
    for (final item in orderItems) {
      final kdsStatus = item['kds_status'] as String?;
      switch (kdsStatus) {
        case KDS_ITEM_STATUS_PREPARING:
          hasPreparingItems = true;
          break;
        case KDS_ITEM_STATUS_READY:
          hasReadyItems = true;
          break;
        case KDS_ITEM_STATUS_PICKED_UP:
          hasPickedUpItems = true;
          break;
      }
    }
    
    if (hasReadyItems) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.teal.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.restaurant_menu,
          color: Colors.white,
          size: 16,
        ),
      );
    } else if (hasPreparingItems) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.orange.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.whatshot,
          color: Colors.white,
          size: 16,
        ),
      );
    } else if (hasPickedUpItems) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.purple.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.pan_tool_alt,
          color: Colors.white,
          size: 16,
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildItemRow(Map<String, dynamic> item, AppLocalizations l10n) {
    final bool isDelivered = item['delivered'] == true;
    final String kdsStatus = item['kds_status'] ?? KDS_ITEM_STATUS_PENDING;
    final bool isAwaitingApproval = item['is_awaiting_staff_approval'] == true;
    final int itemId = item['id'] ?? 0;
    
    final bool canPerformAction = _canPerformAction(itemId);
    final String optimisticState = _optimisticStates[itemId] ?? '';
    
    Widget actionWidget;

    if (isDelivered) {
      actionWidget = Tooltip(
        message: "Müşteriye teslim edildi",
        child: Icon(Icons.check_circle, size: 28, color: Colors.green.shade600),
      );
    } else if (kdsStatus == KDS_ITEM_STATUS_READY || optimisticState == 'picking_up') {
      actionWidget = !canPerformAction
        ? _buildEnhancedLoadingIndicator(Colors.purple.shade600, "Teslim alınıyor...")
        : IconButton(
            icon: const Icon(Icons.pan_tool_alt_outlined, size: 28),
            color: Colors.purple.shade600,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Garson Teslim Al",
            onPressed: () => _handleItemPickup(itemId, l10n),
          );
    } else if (kdsStatus == KDS_ITEM_STATUS_PICKED_UP || optimisticState == 'delivering') {
      actionWidget = !canPerformAction
        ? _buildEnhancedLoadingIndicator(Colors.blue.shade600, "Teslim ediliyor...")
        : IconButton(
            icon: const Icon(Icons.room_service_outlined, size: 28),
            color: Colors.blue.shade600,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Müşteriye Teslim Et",
            onPressed: () => _handleDeliverOrderItem(itemId, l10n),
          );
    } else if (kdsStatus == KDS_ITEM_STATUS_PREPARING) {
      actionWidget = Tooltip(
        message: l10n.kdsStatusPreparing,
        child: Icon(Icons.whatshot, size: 24, color: Colors.orange.shade800)
      );
    } else {
      actionWidget = Tooltip(
        message: "Mutfak için bekliyor",
        child: Icon(Icons.hourglass_empty, size: 22, color: Colors.grey.shade600)
      );
    }

    final String productName = item['menu_item']?['name'] ?? "Bilinmeyen Ürün";
    final String? variantName = item['variant']?['name'];
    final String variantNameDisplay = (variantName != null && variantName.isNotEmpty) ? ' ($variantName)' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Opacity(
              opacity: isDelivered ? 0.6 : 1.0,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "${item['quantity']}x $productName$variantNameDisplay",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: isDelivered ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isAwaitingApproval)
                      TextSpan(
                        text: " [YENİ]",
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          actionWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!widget.isOccupied) {
      return InkWell(
        onTap: widget.onTap,
        child: Card(
          color: Colors.white.withOpacity(0.6),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: Text(
              l10n.tableCellDefaultTitle(widget.table['table_number'].toString()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
          ),
        ),
      );
    }

    final bool isPendingApproval = widget.pendingOrder['status'] == STATUS_PENDING_APPROVAL;
    final bool isPendingSync = widget.pendingOrder['status'] == STATUS_PENDING_SYNC;

    Color cardColor;
    Color borderColor;

    if (isPendingSync) {
      cardColor = Colors.grey.shade400.withOpacity(0.95);
      borderColor = Colors.grey.shade700;
    } else if (isPendingApproval) {
      cardColor = Colors.purple.shade100.withOpacity(0.95);
      borderColor = Colors.purple.shade600;
    } else if (widget.pendingOrder!['status'] == STATUS_READY_FOR_PICKUP || widget.pendingOrder!['status'] == 'ready_for_delivery') {
      cardColor = Colors.teal.shade300.withOpacity(0.9);
      borderColor = Colors.teal.shade600;
    } else if (widget.pendingOrder!['status'] == STATUS_PREPARING) {
      cardColor = Colors.orange.shade100.withOpacity(0.95);
      borderColor = Colors.orange.shade700;
    } else if (widget.pendingOrder!['status'] == STATUS_APPROVED) {
      cardColor = Colors.blue.shade100.withOpacity(0.95);
      borderColor = Colors.blue.shade600;
    } else {
      cardColor = Colors.blueGrey.shade100.withOpacity(0.95);
      borderColor = Colors.blueGrey.shade600;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        color: cardColor,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 2)
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 42.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(l10n),
                  const Divider(),
                  Expanded(
                    child: widget.pendingOrder['order_items'] == null || (widget.pendingOrder['order_items'] as List).isEmpty
                        ? Center(child: Text("Sipariş öğesi yok"))
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: widget.pendingOrder['order_items'].length,
                            itemBuilder: (context, index) {
                              return _buildItemRow(widget.pendingOrder['order_items'][index], l10n);
                            },
                          ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: isPendingSync
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_shopping_cart, size: 18),
                              label: Text(l10n.addOrEditButton),
                              onPressed: widget.onTap,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap
                              ),
                            ),
                          ),
                        ],
                      )
                    : isPendingApproval
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.check_circle, size: 18), label: Text(l10n.buttonApprove), onPressed: widget.onApprove, style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                              const SizedBox(width: 8),
                              Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.cancel, size: 18), label: Text(l10n.buttonReject), onPressed: widget.onReject, style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                iconSize: 24,
                                color: Colors.green.shade800,
                                tooltip: "Ürün ekle veya düzenle",
                                onPressed: widget.onAddItem,
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, color: Colors.blueGrey.shade800),
                                tooltip: "Diğer işlemler",
                                onSelected: (value) {
                                  if (value == 'transfer') {
                                    widget.onTransfer();
                                  } else if (value == 'cancel') {
                                    widget.onCancel();
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'transfer',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Text("Masa Transferi"),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'cancel',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.cancel_outlined, color: Colors.red),
                                        const SizedBox(width: 8),
                                        Text("Siparişi İptal Et"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// lib/widgets/kds/enhanced_kds_order_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../mixins/kds_button_action_mixin.dart';
import '../../services/kds_service.dart';
import '../../utils/currency_formatter.dart';

class EnhancedKdsOrderCard extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String token;
  final bool isLoadingAction;
  final VoidCallback onOrderUpdated;

  const EnhancedKdsOrderCard({
    Key? key,
    required this.orderData,
    required this.token,
    required this.isLoadingAction,
    required this.onOrderUpdated,
  }) : super(key: key);

  @override
  _EnhancedKdsOrderCardState createState() => _EnhancedKdsOrderCardState();
}

class _EnhancedKdsOrderCardState extends State<EnhancedKdsOrderCard>
    with KdsButtonActionMixin<EnhancedKdsOrderCard> {
  
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;
  
  @override
  String get token => widget.token;
  
  @override
  bool get isDisposed => !mounted;

  @override
  void onActionSuccess(String actionType, dynamic result) {
    if (mounted) {
      widget.onOrderUpdated();
    }
  }

  @override
  void onActionError(String actionType, String error) {
    debugPrint('KDS Action Error [$actionType]: $error');
  }

  @override
  void showLoadingFeedback(String message) {
    _showOverlayFeedback(Colors.blue, Icons.hourglass_empty, message);
  }

  @override
  void showSuccessFeedback(String message) {
    _showOverlayFeedback(Colors.green, Icons.check_circle, message);
  }

  @override
  void showErrorFeedback(String message) {
    _showOverlayFeedback(Colors.red, Icons.error, message);
  }

  @override
  void initState() {
    super.initState();
    _overlayEntry = null;
    _overlayTimer = null;
  }

  @override
  void dispose() {
    // 🔥 Safe cleanup with null checks
    _cleanupOverlay();
    disposeKdsButtonActionMixin();
    super.dispose();
  }

  // 🔥 Safe overlay cleanup
  void _cleanupOverlay() {
    try {
      _overlayTimer?.cancel();
      _overlayTimer = null;
      
      if (_overlayEntry?.mounted == true) {
        _overlayEntry?.remove();
      }
      _overlayEntry = null;
    } catch (e) {
      debugPrint('Overlay cleanup error: $e');
    }
  }

  void _showOverlayFeedback(Color color, IconData icon, String message) {
    // 🔥 Enhanced safety checks
    if (!mounted) return;
    
    // Clean up any existing overlay first
    _cleanupOverlay();
    
    try {
      final overlay = Overlay.of(context);
      if (overlay == null) return;
      
      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Center(
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
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      
      overlay.insert(_overlayEntry!);
      
      // 🔥 Safe timer with proper cleanup
      _overlayTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _cleanupOverlay();
        }
      });
      
    } catch (e) {
      debugPrint('Overlay show error: $e');
      _cleanupOverlay();
    }
  }

  // 🔥 Safe action button with enhanced error handling
  Widget _buildActionButton({
    required String actionKey,
    required String actionType,
    required String label,
    required IconData icon,
    required Color color,
    required Map<String, dynamic> parameters,
    required String loadingMessage,
    required String successMessage,
  }) {
    if (!mounted) return const SizedBox.shrink();
    
    final isProcessing = isActionProcessing(actionKey);
    final canPerform = canPerformAction(actionKey);
    
    if (isProcessing) {
      return buildEnhancedLoadingIndicator(
        color: color,
        message: loadingMessage,
        size: 32,
      );
    }
    
    return ElevatedButton.icon(
      onPressed: canPerform && mounted ? () {
        // 🔥 Double-check mounted state before action
        if (!mounted) return;
        
        handleKdsAction(
          actionKey: actionKey,
          actionType: actionType,
          parameters: parameters,
          loadingMessage: loadingMessage,
          successMessage: successMessage,
        );
      } : null,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: canPerform ? color : color.withOpacity(0.5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(60, 32),
      ),
    );
  }

  // 🔥 Safe order item actions with null safety
  List<Widget> _buildOrderItemActions(Map<String, dynamic> orderItem) {
    if (!mounted || orderItem.isEmpty) return [];
    
    try {
      final l10n = AppLocalizations.of(context)!;
      final orderId = _safeGetInt(widget.orderData, 'id');
      final orderItemId = _safeGetInt(orderItem, 'id');
      final String kdsStatus = orderItem['kds_status']?.toString() ?? 'pending_kds';
      
      if (orderId == null || orderItemId == null) {
        return [const SizedBox.shrink()];
      }
      
      List<Widget> actions = [];
      
      switch (kdsStatus) {
        case 'pending_kds':
          actions.add(
            _buildActionButton(
              actionKey: 'preparing_${orderId}_$orderItemId',
              actionType: 'mark_preparing',
              label: l10n.kdsPrepare,
              icon: Icons.whatshot,
              color: Colors.orange,
              parameters: {
                'orderId': orderId,
                'orderItemId': orderItemId,
              },
              loadingMessage: l10n.kdsPreparing,
              successMessage: l10n.kdsPreparationStarted,
            ),
          );
          break;
          
        case 'preparing_kds':
          actions.add(
            _buildActionButton(
              actionKey: 'ready_${orderId}_$orderItemId',
              actionType: 'mark_ready',
              label: l10n.kdsReady,
              icon: Icons.restaurant_menu,
              color: Colors.teal,
              parameters: {
                'orderId': orderId,
                'orderItemId': orderItemId,
              },
              loadingMessage: l10n.kdsMarkingReady,
              successMessage: l10n.kdsProductReady,
            ),
          );
          break;
          
        case 'ready_kds':
          actions.add(
            _buildStatusContainer(l10n.kdsReady, Colors.teal),
          );
          break;
          
        case 'picked_up_kds':
          actions.add(
            _buildStatusContainer(l10n.kdsCompleted, Colors.green),
          );
          break;
          
        default:
          actions.add(
            _buildStatusContainer(l10n.kdsWaiting, Colors.grey),
          );
      }
      
      return actions;
    } catch (e) {
      debugPrint('Error building order item actions: $e');
      return [const SizedBox.shrink()];
    }
  }

  // 🔥 Helper method for status containers
  Widget _buildStatusContainer(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 Safe integer extraction helper
  int? _safeGetInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // 🔥 Safe string extraction helper
  String _safeGetString(Map<String, dynamic> map, String key, [String defaultValue = '']) {
    final value = map[key];
    if (value == null) return defaultValue;
    return value.toString();
  }

  Widget _buildOrderActions() {
    if (!mounted) return const SizedBox.shrink();
    
    try {
      final l10n = AppLocalizations.of(context)!;
      final orderId = _safeGetInt(widget.orderData, 'id');
      final String status = _safeGetString(widget.orderData, 'status', 'approved');
      
      if (orderId == null) return const SizedBox.shrink();
      
      // Sipariş seviyesinde aksiyonlar sadece gerektiğinde göster
      if (status == 'pending_approval') {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _buildActionButton(
            actionKey: 'start_preparation_$orderId',
            actionType: 'start_preparation',
            label: l10n.kdsStartPreparation,
            icon: Icons.play_arrow,
            color: Colors.orange,
            parameters: {
              'orderId': orderId,
              'kdsScreenSlug': 'mutfak',
            },
            loadingMessage: l10n.kdsStartingPreparation,
            successMessage: l10n.kdsPreparationStarted,
          ),
        );
      }
      
      return const SizedBox.shrink();
    } catch (e) {
      debugPrint('Error building order actions: $e');
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return const SizedBox.shrink();
    
    try {
      final orderItems = widget.orderData['order_items'] as List<dynamic>? ?? [];
      final l10n = AppLocalizations.of(context)!;
      
      // 🔥 Safe ID extraction
      final orderId = _safeGetString(widget.orderData, 'id', 'N/A');
      final tempId = _safeGetString(widget.orderData, 'temp_id');
      final displayId = tempId.isNotEmpty && tempId.length > 5 
          ? tempId.substring(0, 5) 
          : (tempId.isNotEmpty ? tempId : orderId);
      
      return Card(
        margin: const EdgeInsets.all(6),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Order Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.kdsOrderNumber(displayId),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _safeGetString(widget.orderData, 'table_number', l10n.kdsPackage),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Order Items
              if (orderItems.isNotEmpty) ...[
                ...orderItems.map((item) {
                  if (item is! Map<String, dynamic>) return const SizedBox.shrink();
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_safeGetString(item, 'quantity', '1')}x ${_safeGetString(item, 'menu_item_name') ?? _safeGetString(item['menu_item'] ?? {}, 'name', l10n.kdsUnknownProduct)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ..._buildOrderItemActions(item),
                          ],
                        ),
                        if (_safeGetString(item, 'notes').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              l10n.kdsNote(_safeGetString(item, 'notes')),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Text(
                      l10n.kdsNoItemsInOrder,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
              
              // Order Actions
              _buildOrderActions(),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error building KDS card: $e');
      final l10n = AppLocalizations.of(context);
      return Card(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n?.kdsCardError ?? 'An error occurred while loading the card.',
            style: TextStyle(color: Colors.red.shade600),
          ),
        ),
      );
    }
  }
}
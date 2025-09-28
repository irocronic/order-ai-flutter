// lib/screens/new_order_screen.dart

import '../services/notification_center.dart';
import '../services/refresh_manager.dart';
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
import '../controllers/new_order_controller.dart';
import '../widgets/new_order/dialogs/new_order_dialogs.dart';
import '../widgets/categorized_menu_list_view.dart';
import '../widgets/new_order_basket_view.dart';

class NewOrderScreen extends StatefulWidget {
  final String token;
  final dynamic table;
  final int businessId;

  const NewOrderScreen({
    Key? key,
    required this.token,
    required this.table,
    required this.businessId,
  }) : super(key: key);

  @override
  _NewOrderScreenState createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  late NewOrderController _controller;
  late AppLocalizations _l10n;
  bool _didChangeDependenciesRun = false;

  @override
  void initState() {
    super.initState();
    NotificationCenter.instance.addObserver('refresh_all_screens', (data) {
      debugPrint('[NewOrderScreen] 📡 Global refresh received: ${data['event_type']}');
      if (mounted && _didChangeDependenciesRun && !_controller.isLoading) {
        final refreshKey = 'new_order_screen_${widget.table['id']}_${widget.businessId}';
        RefreshManager.throttledRefresh(refreshKey, () async {
          await _refreshMenuData();
        });
      }
    });
    NotificationCenter.instance.addObserver('screen_became_active', (data) {
      debugPrint('[NewOrderScreen] 📱 Screen became active notification received');
      if (mounted && _didChangeDependenciesRun && !_controller.isLoading) {
        final refreshKey = 'new_order_screen_active_${widget.table['id']}_${widget.businessId}';
        RefreshManager.throttledRefresh(refreshKey, () async {
          await _refreshMenuData();
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didChangeDependenciesRun) {
      _l10n = AppLocalizations.of(context)!;
      _controller = NewOrderController(
        token: widget.token,
        businessId: widget.businessId,
        table: widget.table,
        onStateUpdate: (VoidCallback fn) {
            if (mounted) {
              setState(fn);
            }
        },
        showSnackBarCallback: (String message, {bool isError = false}) {
            if (mounted) {
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: isError ? Colors.redAccent : Colors.green,
                  duration: Duration(seconds: isError ? 3 : 2),
                ),
              );
            }
        },
        l10n: _l10n, // ✅ GÜNCELLEME: Eksik olan l10n parametresi eklendi.
      );
      _controller.initializeScreen().then((success) {
          if (mounted && success && _controller.isSplitTable == null) {
            _promptTableType();
          } else if (mounted && !success){
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_controller.errorMessage.isNotEmpty ? _controller.errorMessage : _l10n.newOrderLoadingInitialData)),
              );
            }
      });
      _didChangeDependenciesRun = true;
    }
  }

  Future<void> _refreshMenuData() async {
    if (mounted && !_controller.isLoading) {
      try {
        await _controller.initializeScreen();
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('[NewOrderScreen] Menu refresh error: $e');
      }
    }
  }

  void _promptTableType() {
    NewOrderDialogs.promptTableType(
      context: context,
      onSelected: (isSplit, owners) {
          _controller.handleTableTypeSelected(isSplit, owners);
      },
      onCancel: () {
        if (mounted && _controller.isSplitTable == null) {
          Navigator.of(context).pop();
        }
      }
    );
  }

  void _promptTableOwners() {
    NewOrderDialogs.promptTableOwners(
      context: context,
      initialOwners: _controller.tableOwners,
      onConfirm: _controller.handleTableOwnersUpdated,
    );
  }
  
  Future<void> _submitOrder() async {
    if (_controller.isLoading) return;

    debugPrint("[NewOrderScreen] _submitOrder çağrıldı. Controller'dan sonuç bekleniyor...");
    final bool success = await _controller.handleCreateOrder();
    debugPrint("[NewOrderScreen] Controller'dan sonuç geldi: $success");

    if (success && mounted) {
      debugPrint("[NewOrderScreen] Sipariş başarılı, ana ekrana popUntil ile kesin gidiliyor!");
      Navigator.of(context).popUntil((route) => route.isFirst); // GARANTİ NAVİGASYON!
    } else if (mounted) {
      debugPrint("[NewOrderScreen] İşlem başarısız oldu, ekranda kalınıyor.");
    }
  }

  @override
  Widget build(BuildContext context) {
      if (!_didChangeDependenciesRun) {
          return Scaffold(
              backgroundColor: Colors.blue.shade900,
              body: const Center(child: CircularProgressIndicator(color: Colors.white))
          );
      }

      if (_controller.isLoading && _controller.isSplitTable == null) {
        return _buildLoadingOrErrorScaffold(_l10n.newOrderLoadingData);
      } else if (_controller.errorMessage.isNotEmpty && _controller.isSplitTable == null) {
        return _buildLoadingOrErrorScaffold(_controller.errorMessage);
      } else if (_controller.isSplitTable == null && !_controller.isLoading) {
        return _buildLoadingOrErrorScaffold(_l10n.newOrderWaitingForTableType);
      }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _l10n.newOrderTitle(widget.table['table_number'].toString()),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _controller.isLoading ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (!_controller.isLoading && _controller.isSplitTable != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: Icon(_controller.isSplitTable == true ? Icons.people : Icons.person),
              label: Text(_controller.isSplitTable == true ? _l10n.newOrderTableTypeSplit : _l10n.newOrderTableTypeSingle),
              onPressed: _controller.isLoading ? null : () {
                  _controller.isSplitTable = null;
                  _controller.tableOwners = [];
                  _controller.basket.clear();
                  _controller.onStateUpdate(() {});
                  _promptTableType();
              },
            )
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF283593), Color(0xFF455A64), Color(0xFF455A64)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_controller.errorMessage.isNotEmpty && _controller.isSplitTable != null && !_controller.isLoading)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_controller.errorMessage, style: const TextStyle(color: Colors.redAccent)),
                ),
              if (_controller.isSplitTable == true && !_controller.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _controller.tableOwners.where((o) => o.isNotEmpty).isEmpty 
                            ? _l10n.newOrderNoOwnersEntered 
                            : _l10n.newOrderOwnersList(_controller.tableOwners.join(', ')),
                          style: TextStyle(fontWeight: FontWeight.bold, color: _controller.tableOwners.where((o) => o.isNotEmpty).isEmpty ? Colors.orangeAccent : Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white70, size: 20,),
                        tooltip: _l10n.newOrderEditOwnersTooltip,
                        onPressed: _controller.isLoading ? null : _promptTableOwners,
                      )
                    ],
                  ),
                ),
              Expanded(
                child: CategorizedMenuListView(
                  menuItems: _controller.menuItems,
                  categories: _controller.categories,
                  tableUsers: _controller.tableOwners,
                  onItemSelected: _controller.isLoading ? (_, __, ___, ____, _____) {} : _controller.addToBasket,
                ),
              ),
              if (!_controller.isLoading) ...[
                const Divider(color: Colors.white70),
                NewOrderBasketView(
                  basket: _controller.basket,
                  allMenuItems: _controller.menuItems,
                  onRemoveItem: _controller.isLoading ? (_) {} : _controller.removeFromBasket,
                  totalAmount: _controller.basketTotal,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.8),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: Colors.grey.withOpacity(0.5)
                      ),
                      onPressed: _controller.isLoading || _controller.basket.isEmpty || (_controller.isSplitTable == true && _controller.tableOwners.where((o) => o.isNotEmpty).length < 2)
                          ? null
                          : _submitOrder,
                      child: _controller.isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black))
                          : Text(_l10n.newOrderCreateOrderButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOrErrorScaffold(String message) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
          title: Text(
            l10n.newOrderTitle(widget.table['table_number'].toString()),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
            flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ Color(0xFF283593), Color(0xFF455A64), Color(0xFF455A64)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [
                 Colors.blue.shade900.withOpacity(0.9),
                 Colors.blue.shade400.withOpacity(0.8),
               ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
            ),
          ),
        child: Center(
          child: (message == l10n.newOrderLoadingData || message == l10n.newOrderWaitingForTableType)
              ? const CircularProgressIndicator(color: Colors.white)
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }
}
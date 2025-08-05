// lib/widgets/setup_wizard/step_stock_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/api_service.dart';
import '../../models/menu_item.dart';
import '../../models/menu_item_variant.dart';

class StepStockWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepStockWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
    required this.onSkip,
  }) : super(key: key);

  @override
  _StepStockWidgetState createState() => _StepStockWidgetState();
}

class _StepStockWidgetState extends State<StepStockWidget> {
  bool _isLoadingPageData = true;
  String _errorMessage = '';
  String _successMessage = '';

  List<MenuItem> _menuItemsWithVariants = [];
  Map<int, dynamic> _existingStockMap = {};
  Map<int, TextEditingController> _quantityControllers = {};
  Map<int, bool> _isSavingStockForVariant = {};

  final Map<int, bool> _expanded = {};

  late final AppLocalizations l10n;
  bool _didFetchData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      l10n = AppLocalizations.of(context)!;
      _fetchInitialData();
      _didFetchData = true;
    }
  }

  @override
  void dispose() {
    _quantityControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPageData = true;
      _errorMessage = '';
      _successMessage = '';
    });
    try {
      final menuItemsData =
          await ApiService.fetchMenuItemsForBusiness(widget.token);
      final stockData = await ApiService.fetchBusinessStock(widget.token);

      if (mounted) {
        _menuItemsWithVariants = menuItemsData
            .map((itemJson) => MenuItem.fromJson(itemJson))
            .where((item) => item.variants != null && item.variants!.isNotEmpty)
            .toList();

        _existingStockMap = {
          for (var stock in stockData)
            if (stock['variant'] is int)
              stock['variant']: stock
            else if (stock['variant'] is Map && stock['variant']['id'] != null)
              stock['variant']['id']: stock
        };

        _quantityControllers.forEach((_, controller) => controller.dispose());
        _quantityControllers = {};
        _isSavingStockForVariant = {};

        for (var item in _menuItemsWithVariants) {
          for (var variant in item.variants!) {
            final currentStock = _existingStockMap[variant.id];
            _quantityControllers[variant.id] = TextEditingController(
              text:
                  currentStock != null ? currentStock['quantity'].toString() : '0',
            );
            _isSavingStockForVariant[variant.id] = false;
          }
        }
        setState(() => _isLoadingPageData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.errorLoadingInitialData(e.toString().replaceFirst("Exception: ", ""));
          _isLoadingPageData = false;
        });
      }
    }
  }

  Future<void> _saveStock(MenuItemVariant variant) async {
    if (!mounted) return;
    final controller = _quantityControllers[variant.id];
    final itemName = menuItemNameForVariant(l10n, variant.menuItem);

    if (controller == null || controller.text.trim().isEmpty) {
      setState(() => _errorMessage = l10n.setupStockErrorEnterQuantity(itemName, variant.name));
      _clearMessagesAfterDelay();
      return;
    }
    final quantity = int.tryParse(controller.text.trim());
    if (quantity == null || quantity < 0) {
      setState(() => _errorMessage = l10n.setupStockErrorInvalidQuantity(itemName, variant.name));
      _clearMessagesAfterDelay();
      return;
    }

    setState(() {
      _isSavingStockForVariant[variant.id] = true;
      _successMessage = '';
      _errorMessage = '';
    });

    try {
      final existingStockEntry = _existingStockMap[variant.id];
      await ApiService.createOrUpdateStock(
        widget.token,
        variantId: variant.id,
        quantity: quantity,
        stockId: existingStockEntry?['id'] as int?,
      );
      if (mounted) {
        setState(() {
          _successMessage = l10n.setupStockSuccessUpdated(itemName, variant.name, quantity.toString());
        });
        await _fetchInitialData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.setupStockErrorUpdating(itemName, variant.name, e.toString().replaceFirst("Exception: ", ""));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingStockForVariant[variant.id] = false);
        _clearMessagesAfterDelay();
      }
    }
  }

  void _incrementStock(int variantId) {
    final controller = _quantityControllers[variantId];
    if (controller == null) return;
    int currentValue = int.tryParse(controller.text) ?? 0;
    currentValue++;
    setState(() {
      controller.text = currentValue.toString();
    });
  }

  void _decrementStock(int variantId) {
    final controller = _quantityControllers[variantId];
    if (controller == null) return;
    int currentValue = int.tryParse(controller.text) ?? 0;
    if (currentValue > 0) {
      currentValue--;
      setState(() {
        controller.text = currentValue.toString();
      });
    }
  }

  void _clearMessagesAfterDelay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && (_successMessage.isNotEmpty || _errorMessage.isNotEmpty)) {
        setState(() {
          _successMessage = '';
          _errorMessage = '';
        });
      }
    });
  }

  String menuItemNameForVariant(AppLocalizations l10n, int menuItemId) {
    final item = _menuItemsWithVariants.firstWhere(
      (mi) => mi.id == menuItemId,
      orElse: () => MenuItem(
          id: 0,
          name: l10n.setupStockUnknownProduct,
          image: '',
          description: ''),
    );
    return item.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = const TextStyle(color: Colors.white);
    
    if (_isLoadingPageData) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_menuItemsWithVariants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage.isNotEmpty
                ? _errorMessage
                : l10n.setupStockErrorNoVariants,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: _errorMessage.isNotEmpty
                  ? Colors.redAccent
                  : Colors.white70,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.setupStockDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
            ),
          ),
          if (_successMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _successMessage,
                style: const TextStyle(
                    color: Colors.lightGreenAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _errorMessage,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          RefreshIndicator(
            onRefresh: _fetchInitialData,
            color: Colors.white,
            backgroundColor: Colors.blue.shade700,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _menuItemsWithVariants.length,
              itemBuilder: (context, itemIndex) {
                final menuItem = _menuItemsWithVariants[itemIndex];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 0,
                  color: Colors.white.withOpacity(0.1),
                   shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  child: ExpansionTile(
                    key: ValueKey(menuItem.id),
                    iconColor: Colors.white70,
                    collapsedIconColor: Colors.white70,
                    initiallyExpanded: _expanded.containsKey(menuItem.id)
                        ? _expanded[menuItem.id]!
                        : (_menuItemsWithVariants.length < 3 || itemIndex < 2),
                    onExpansionChanged: (isOpen) {
                      setState(() => _expanded[menuItem.id] = isOpen);
                    },
                    title: Text(
                      menuItem.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    children: menuItem.variants?.map<Widget>((variant) {
                          final controller = _quantityControllers[variant.id];
                          final currentStockData = _existingStockMap[variant.id];
                          String lastUpdated = l10n.setupStockNoStockEntered;
                          if (currentStockData != null &&
                              currentStockData['last_updated'] != null) {
                            try {
                              final localDateTime = DateTime.parse(currentStockData['last_updated']).toLocal();
                              final formattedDate = DateFormat(l10n.dateTimeFormat, l10n.localeName).format(localDateTime);
                              lastUpdated = l10n.setupStockLastUpdate(formattedDate);
                            } catch (_) {}
                          }
                          final isCurrentlySaving =
                              _isSavingStockForVariant[variant.id] ?? false;

                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                            child: Column(
                              children: [
                                const Divider(color: Colors.white24),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(variant.name,
                                              style: textStyle.copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500)),
                                          Text(lastUpdated,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white.withOpacity(0.6))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline,
                                          color: Colors.red.shade300),
                                      onPressed: isCurrentlySaving
                                          ? null
                                          : () => _decrementStock(variant.id),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: TextFormField(
                                        controller: controller,
                                        style: textStyle,
                                        textAlign: TextAlign.center,
                                        enabled: !isCurrentlySaving,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.black.withOpacity(0.2),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8.0,
                                                  vertical: 10.0),
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add_circle_outline,
                                          color: Colors.green.shade300),
                                      onPressed: isCurrentlySaving
                                          ? null
                                          : () => _incrementStock(variant.id),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      onPressed: isCurrentlySaving
                                          ? null
                                          : () => _saveStock(variant),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0, vertical: 10.0),
                                        minimumSize: const Size(60, 38),
                                      ),
                                      child: isCurrentlySaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            )
                                          : Text(l10n.buttonSave,
                                              style:
                                                  const TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList() ??
                        [],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// lib/screens/create_purchase_order_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/supplier.dart';
import '../models/ingredient.dart';
import '../models/purchase_order_item.dart';
import '../services/procurement_service.dart';
import '../services/ingredient_service.dart';
import '../services/user_session.dart';
import '../utils/currency_formatter.dart';
import '../widgets/universal_quantity_input.dart';

class CreatePurchaseOrderScreen extends StatefulWidget {
  const CreatePurchaseOrderScreen({Key? key}) : super(key: key);

  @override
  _CreatePurchaseOrderScreenState createState() => _CreatePurchaseOrderScreenState();
}

class _CreatePurchaseOrderScreenState extends State<CreatePurchaseOrderScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  
  List<Ingredient> _availableIngredients = [];
  
  List<PurchaseOrderItem> _orderItems = [];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ProcurementService.fetchSuppliers(UserSession.token),
        IngredientService.fetchIngredients(UserSession.token),
      ]);
      if (mounted) {
        setState(() {
          _suppliers = results[0] as List<Supplier>;
          _availableIngredients = results[1] as List<Ingredient>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addIngredientToOrder() {
    final l10n = AppLocalizations.of(context)!;
    Ingredient? selectedIngredient;
    final priceController = TextEditingController();
    final alertThresholdController = TextEditingController();
    double finalQuantity = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.ingredientAddToOrder),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Malzeme Seçimi
                    DropdownButtonFormField<Ingredient>(
                      value: selectedIngredient,
                      hint: Text(l10n.ingredientSelect),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.ingredientSelect,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: const Icon(Icons.inventory_2),
                      ),
                      items: _availableIngredients.map((ing) {
                        return DropdownMenuItem(
                          value: ing, 
                          child: Text("${ing.name} (${ing.unitAbbreviation})")
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedIngredient = val),
                    ),
                    const SizedBox(height: 16),
                    
                    // YENİ: Universal Quantity Input
                    UniversalQuantityInput(
                      selectedIngredient: selectedIngredient,
                      onQuantityChanged: (convertedValue) {
                        finalQuantity = convertedValue;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Birim Fiyat
                    TextFormField(
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: l10n.purchaseOrderUnitPrice,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    
                    // *** YENİ: UYARI EŞİĞİ ALANI ***
                    TextFormField(
                      controller: alertThresholdController,
                      decoration: InputDecoration(
                        labelText: l10n.alertThresholdLabel,
                        hintText: l10n.alertThresholdHint,
                        suffixText: selectedIngredient?.unitAbbreviation,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.orange.shade50,
                        prefixIcon: const Icon(Icons.warning_amber, color: Colors.orange),
                        helperText: l10n.alertThresholdHelper,
                        helperMaxLines: 2,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    // *** YENİ ALAN SONU ***
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: Text(l10n.dialogButtonCancel)
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (selectedIngredient != null && 
                        finalQuantity > 0 && 
                        priceController.text.isNotEmpty) {
                      
                      // *** YENİ: Alert threshold'u da item'a ekle ***
                      final alertThreshold = alertThresholdController.text.isNotEmpty 
                          ? double.tryParse(alertThresholdController.text) 
                          : null;
                      
                      setState(() {
                        _orderItems.add(PurchaseOrderItem(
                          ingredientId: selectedIngredient!.id,
                          ingredientName: selectedIngredient!.name,
                          unitAbbreviation: selectedIngredient!.unitAbbreviation,
                          quantity: finalQuantity, // Artık dönüştürülmüş değer
                          unitPrice: double.tryParse(priceController.text) ?? 0,
                          alertThreshold: alertThreshold, // *** YENİ ALAN ***
                        ));
                      });
                      Navigator.pop(ctx);
                    } else if (finalQuantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.validQuantityError))
                      );
                    }
                  },
                  child: Text(l10n.addButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double get _totalCost {
    return _orderItems.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));
  }

  Future<void> _submitOrder() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedSupplier == null || _orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.purchaseOrderValidationError)));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ProcurementService.createPurchaseOrder(UserSession.token, {
        'supplier': _selectedSupplier!.id,
        'items': _orderItems.map((item) => item.toJsonForSubmit()).toList(),
      });
      if(mounted) {
        Navigator.pop(context, true); // Go back to list and trigger refresh
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${l10n.errorPrefix}: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.purchaseOrderCreateTitle, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButtonFormField<Supplier>(
                        value: _selectedSupplier,
                        hint: Text(l10n.purchaseOrderSelectSupplier),
                        isExpanded: true,
                        items: _suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (val) => setState(() => _selectedSupplier = val),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _orderItems.length,
                        itemBuilder: (context, index) {
                          final item = _orderItems[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              title: Text(item.ingredientName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item.quantity} ${item.unitAbbreviation} x ${CurrencyFormatter.format(item.unitPrice)}'),
                                  // *** YENİ: Uyarı eşiği gösterimi ***
                                  if (item.alertThreshold != null)
                                    Text(
                                      '${l10n.alertThresholdDisplay}: ${item.alertThreshold} ${item.unitAbbreviation}',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Text(CurrencyFormatter.format(item.quantity * item.unitPrice)),
                              leading: Icon(
                                item.alertThreshold != null ? Icons.warning_amber : Icons.inventory_2,
                                color: item.alertThreshold != null ? Colors.orange : Colors.blue,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('${l10n.purchaseOrderTotalCost}: ${CurrencyFormatter.format(_totalCost)}', style: Theme.of(context).textTheme.headlineSmall),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addIngredientToOrder,
        icon: const Icon(Icons.add),
        label: Text(l10n.purchaseOrderAddItemButton),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: _submitOrder,
          child: Text(l10n.purchaseOrderSaveButton),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ),
    );
  }
}
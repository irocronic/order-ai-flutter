// lib/screens/ingredient_management_screen.dart

import 'package:flutter/material.dart';
import 'package.intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/ingredient.dart';
import '../services/ingredient_service.dart';
import '../services/procurement_service.dart'; // YENİ: Tedarikçi servisi
import '../services/user_session.dart';
import '../models/unit_of_measure.dart';
import '../models/supplier.dart'; // YENİ: Tedarikçi modeli
import 'ingredient_history_screen.dart';

class IngredientManagementScreen extends StatefulWidget {
  const IngredientManagementScreen({Key? key}) : super(key: key);

  @override
  _IngredientManagementScreenState createState() =>
      _IngredientManagementScreenState();
}

class _IngredientManagementScreenState extends State<IngredientManagementScreen> {
  late Future<List<Ingredient>> _ingredientsFuture;
  
  // +++ YENİ STATE DEĞİŞKENLERİ +++
  final Set<int> _selectedIngredientIds = {};
  bool get _isSelectionMode => _selectedIngredientIds.isNotEmpty;
  // +++++++++++++++++++++++++++++++

  @override
  void initState() {
    super.initState();
    _ingredientsFuture = IngredientService.fetchIngredients(UserSession.token);
  }

  void _refreshIngredients() {
    if (!mounted) return;
    setState(() {
      // Seçim modunu sıfırla ve verileri yeniden çek
      _selectedIngredientIds.clear();
      _ingredientsFuture = IngredientService.fetchIngredients(UserSession.token);
    });
  }

  // +++ YENİ METOT: Seçimi değiştirir +++
  void _toggleSelection(int ingredientId) {
    if (!mounted) return;
    setState(() {
      if (_selectedIngredientIds.contains(ingredientId)) {
        _selectedIngredientIds.remove(ingredientId);
      } else {
        _selectedIngredientIds.add(ingredientId);
      }
    });
  }
  
  // +++ YENİ METOT: Tedarikçi seçme ve e-posta gönderme +++
  Future<void> _showSupplierSelectionAndSendEmail() async {
    final l10n = AppLocalizations.of(context)!;
    
    if (_selectedIngredientIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.ingredientErrorNoItemsSelected),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    try {
      // Tedarikçileri çek
      final suppliers = await ProcurementService.fetchSuppliers(UserSession.token);
      if (!mounted) return;

      if (suppliers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.ingredientErrorNoSuppliers),
          backgroundColor: Colors.orange,
        ));
        return;
      }
      
      Supplier? selectedSupplier;
      
      // Tedarikçi seçme diyalogunu göster
      final bool? shouldSend = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(l10n.ingredientSelectSupplierTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.ingredientSelectSupplierContent),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Supplier>(
                      value: selectedSupplier,
                      hint: Text(l10n.ingredientSelectSupplierHint),
                      isExpanded: true,
                      items: suppliers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                      onChanged: (val) => setDialogState(() => selectedSupplier = val),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.dialogButtonCancel)),
                  ElevatedButton(
                    onPressed: selectedSupplier == null ? null : () => Navigator.pop(dialogContext, true),
                    child: Text(l10n.sendButton),
                  ),
                ],
              );
            }
          );
        },
      );

      // E-postayı gönder
      if (shouldSend == true && selectedSupplier != null) {
        await IngredientService.sendLowStockEmailToSupplier(
          token: UserSession.token,
          supplierId: selectedSupplier.id,
          ingredientIds: _selectedIngredientIds.toList(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.ingredientSuccessEmailSent),
            backgroundColor: Colors.green,
          ));
          // İşlem sonrası seçimi temizle
          setState(() {
            _selectedIngredientIds.clear();
          });
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.ingredientErrorEmailSending(e.toString())),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _showAdjustStockDialog(Ingredient ingredient) async {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedMovementType = 'ADDITION';

    final Map<String, String> movementTypes = {
      'ADDITION': l10n.stockMovementAddition,
      'WASTAGE': l10n.stockMovementWastage,
      'ADJUSTMENT_IN': l10n.stockMovementAdjustmentIn,
      'ADJUSTMENT_OUT': l10n.stockMovementAdjustmentOut,
    };

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(l10n.ingredientAdjustStockTitle(ingredient.name), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMovementType,
                      decoration: InputDecoration(
                        labelText: l10n.stockMovementTypeLabel,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: movementTypes.entries.map((entry) {
                        return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                      }).toList(),
                      onChanged: (value) => setDialogState(() => selectedMovementType = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        labelText: l10n.quantity,
                        suffixText: ingredient.unitAbbreviation,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return l10n.validatorRequiredField;
                        final double? quantity = double.tryParse(value.replaceAll(',', '.'));
                        if (quantity == null || quantity <= 0) return l10n.validatorInvalidPositiveNumber;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.descriptionLabel,
                        hintText: l10n.descriptionHintOptional,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.dialogButtonCancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await IngredientService.adjustStock(
                          token: UserSession.token,
                          ingredientId: ingredient.id,
                          movementType: selectedMovementType!,
                          quantityChange: double.parse(quantityController.text.replaceAll(',', '.')),
                          description: descriptionController.text.trim(),
                        );
                        Navigator.pop(dialogContext);
                        _refreshIngredients();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.ingredientSuccessStockUpdate), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                         if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
                         }
                      }
                    }
                  },
                  child: Text(l10n.buttonSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddIngredientDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    
    UnitOfMeasure? selectedUnit;
    List<UnitOfMeasure>? availableUnits;
    String? unitFetchError;

    final Future<void> fetchUnitsFuture = IngredientService.fetchUnits(UserSession.token)
      .then((units) {
        if (mounted) {
          availableUnits = units;
          if (units.isNotEmpty) {
            selectedUnit = units.first;
          }
        }
      }).catchError((e) {
        if (mounted) {
          unitFetchError = e.toString();
        }
      });

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return FutureBuilder(
              future: fetchUnitsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    content: const Center(
                      heightFactor: 2,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (unitFetchError != null) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(l10n.errorTitle),
                    content: Text(l10n.ingredientErrorFetchUnits(unitFetchError!)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.dialogButtonClose),
                      ),
                    ],
                  );
                }

                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(l10n.ingredientAddTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: l10n.ingredientNameLabel,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(Icons.inventory_2),
                          ),
                          validator: (value) => (value == null || value.trim().isEmpty) ? l10n.validatorRequiredField : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: quantityController,
                          decoration: InputDecoration(
                            labelText: l10n.ingredientInitialStockLabel,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(Icons.scale),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return l10n.validatorRequiredField;
                            if (double.tryParse(value.replaceAll(',', '.')) == null) return l10n.validatorInvalidNumber;
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (availableUnits != null)
                          DropdownButtonFormField<UnitOfMeasure>(
                            value: selectedUnit,
                            decoration: InputDecoration(
                              labelText: l10n.ingredientUnitLabel,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: const Icon(Icons.straighten),
                            ),
                            items: availableUnits!.map((unit) {
                              return DropdownMenuItem<UnitOfMeasure>(
                                value: unit,
                                child: Text(unit.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedUnit = value;
                              });
                            },
                            validator: (value) => value == null ? l10n.ingredientErrorSelectUnit : null,
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(l10n.dialogButtonCancel),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          try {
                            await IngredientService.createIngredient(
                              token: UserSession.token,
                              name: nameController.text.trim(),
                              stockQuantity: double.parse(quantityController.text.replaceAll(',', '.')),
                              unitId: selectedUnit!.id,
                            );
                            Navigator.pop(dialogContext);
                            _refreshIngredients();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.ingredientSuccessAdd),
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.errorGeneral(e.toString())),
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            }
                          }
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? l10n.ingredientSelectItems : l10n.ingredientManagementTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selectedIngredientIds.clear()),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900.withOpacity(0.9), Colors.blue.shade400.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<Ingredient>>(
          future: _ingredientsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    l10n.errorGeneral(snapshot.error.toString()),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 64,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.ingredientNoItems,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final ingredients = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => _refreshIngredients(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = ingredients[index];
                  final isSelected = _selectedIngredientIds.contains(ingredient.id);
                  final bool isStockLow = ingredient.alertThreshold != null &&
                      ingredient.stockQuantity <= ingredient.alertThreshold!;
                  final bool notificationSent = ingredient.lowStockNotificationSent;

                  return Card(
                    color: isSelected ? Colors.blue.shade100.withOpacity(0.95) : Colors.white.withOpacity(0.92),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isStockLow ? Colors.red.shade400 : (isSelected ? Colors.blue.shade700 : Colors.transparent),
                        width: 2,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _toggleSelection(ingredient.id),
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isStockLow ? Colors.red.shade100 : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isStockLow ? Icons.warning_amber_rounded : Icons.inventory_2,
                          color: isStockLow ? Colors.red.shade700 : Colors.blue.shade700,
                        ),
                      ),
                      title: Text(
                        ingredient.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.ingredientStockLabel(
                                ingredient.stockQuantity.toString(),
                                ingredient.unitAbbreviation,
                              ),
                              style: TextStyle(
                                color: isStockLow ? Colors.red.shade600 : Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: isStockLow ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (isStockLow && notificationSent) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.mark_email_read_outlined, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.ingredientNotificationSent,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      trailing: _isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (bool? value) => _toggleSelection(ingredient.id),
                              activeColor: Colors.blue.shade700,
                            )
                          : PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              tooltip: l10n.ingredientMenuTooltip,
                              onSelected: (value) {
                                if (value == 'adjust') {
                                  _showAdjustStockDialog(ingredient);
                                } else if (value == 'history') {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => IngredientHistoryScreen(
                                      ingredientId: ingredient.id,
                                      ingredientName: ingredient.name,
                                    )
                                  ));
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'adjust',
                                  child: Row(children: [const Icon(Icons.tune, color: Colors.black54), const SizedBox(width: 8), Text(l10n.ingredientMenuAdjustStock)]),
                                ),
                                PopupMenuItem<String>(
                                  value: 'history',
                                  child: Row(children: [const Icon(Icons.history, color: Colors.black54), const SizedBox(width: 8), Text(l10n.ingredientMenuHistory)]),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: _showSupplierSelectionAndSendEmail,
              backgroundColor: Colors.teal.shade400,
              foregroundColor: Colors.white,
              tooltip: l10n.ingredientSendEmailToSupplier,
              icon: const Icon(Icons.email_outlined),
              label: Text(l10n.sendButton),
            )
          : FloatingActionButton.extended(
              onPressed: _showAddIngredientDialog,
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              tooltip: l10n.ingredientAddTitle,
              icon: const Icon(Icons.add),
              label: Text(l10n.addButton),
              elevation: 6,
            ),
    );
  }
}
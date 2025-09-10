// lib/screens/recipe_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/recipe_service.dart';
import '../services/ingredient_service.dart';
import '../models/menu_item_variant.dart';
import '../models/ingredient.dart';
import '../models/unit_of_measure.dart';
import '../services/user_session.dart';
import '../widgets/universal_quantity_input.dart';

class RecipeManagementScreen extends StatefulWidget {
  final String token;
  final MenuItemVariant variant;

  const RecipeManagementScreen({
    Key? key,
    required this.token,
    required this.variant,
  }) : super(key: key);

  @override
  _RecipeManagementScreenState createState() => _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends State<RecipeManagementScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _recipeItems = [];
  List<Ingredient> _availableIngredients = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        RecipeService.fetchRecipeForVariant(widget.token, widget.variant.id),
        IngredientService.fetchIngredients(widget.token),
      ]);
      if (mounted) {
        setState(() {
          _recipeItems = results[0];
          
          // === HATA DÜZELTME BURADA ===
          // IngredientService.fetchIngredients zaten List<Ingredient> döndürüyor
          _availableIngredients = results[1] as List<Ingredient>;
          // === /HATA DÜZELTME SONU ===
              
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Veri alınamadı: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddIngredientDialog() async {
    final l10n = AppLocalizations.of(context)!;
    Ingredient? selectedIngredient;
    double finalQuantity = 0;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(l10n.ingredientAddToRecipe, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Ingredient>(
                      value: selectedIngredient,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.ingredientSelect,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: _availableIngredients.map((ing) {
                        return DropdownMenuItem(
                          value: ing,
                          child: Text(
                              "${ing.name} (${ing.unitAbbreviation})",
                              overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedIngredient = value;
                        });
                      },
                      validator: (value) => value == null ? l10n.validatorRequiredField : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // YENİ: Universal Quantity Input
                    UniversalQuantityInput(
                      selectedIngredient: selectedIngredient,
                      onQuantityChanged: (convertedValue) {
                        finalQuantity = convertedValue;
                      },
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
                    if (formKey.currentState!.validate() && finalQuantity > 0) {
                      try {
                        await RecipeService.addIngredientToRecipe(
                          widget.token,
                          widget.variant.id,
                          selectedIngredient!.id,
                          finalQuantity, // Artık dönüştürülmüş değer
                        );
                        Navigator.pop(dialogContext);
                        _fetchData();
                      } catch (e) {
                         if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Hata: $e"),
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            )
                           );
                         }
                      }
                    } else if (finalQuantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Lütfen geçerli bir miktar girin"))
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String appBarTitle = "${l10n.recipeTitle}: ${widget.variant.name}";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: _recipeItems.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      size: 64,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.recipeNoIngredients,
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
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _recipeItems.length,
                            itemBuilder: (context, index) {
                              final item = _recipeItems[index];
                              return Card(
                                color: Colors.white.withOpacity(0.92),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    item['ingredient_name'] ?? 'Bilinmeyen Malzeme',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${l10n.quantity}: ${item['quantity']} ${item['unit_abbreviation']}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red.shade400,
                                    ),
                                    onPressed: () async {
                                      // Silme onayı diyalogu
                                      final bool? confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: const Text('Malzemeyi Sil'),
                                            content: Text('Bu malzemeyi reçeteden kaldırmak istediğinize emin misiniz?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: Text(l10n.dialogButtonCancel),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text('Sil'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      
                                      if (confirm == true) {
                                        await RecipeService.deleteRecipeItem(widget.token, item['id']);
                                        _fetchData(); // Listeyi yenile
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddIngredientDialog,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.add),
        label: Text(l10n.addButton),
        tooltip: l10n.ingredientAddToRecipe,
        elevation: 6,
      ),
    );
  }
}
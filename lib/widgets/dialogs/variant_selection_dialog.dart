// lib/widgets/dialogs/variant_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../models/menu_item_variant.dart';
import '../../services/api_service.dart';
import '../shared/image_display.dart'; // buildImage için
import '../../utils/currency_formatter.dart';

class VariantSelectionDialog extends StatefulWidget {
  final MenuItem item;
  final List<String> tableUsers;
  final int initialQuantity;
  final Function(MenuItem item, MenuItemVariant? variant, List<MenuItemVariant> extras, String? tableUser, int quantity) onItemSelected;

  const VariantSelectionDialog({
    Key? key,
    required this.item,
    required this.tableUsers,
    required this.initialQuantity,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  _VariantSelectionDialogState createState() => _VariantSelectionDialogState();
}

class _VariantSelectionDialogState extends State<VariantSelectionDialog> {
  late List<MenuItemVariant> normalVariants;
  late List<MenuItemVariant> extraVariants;

  MenuItemVariant? selectedNormalVariant;
  List<MenuItemVariant> selectedExtras = [];
  String? selectedTableUser;
  late int _currentQuantity;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    normalVariants = widget.item.variants?.where((v) => !v.isExtra).toList() ?? [];
    extraVariants = widget.item.variants?.where((v) => v.isExtra).toList() ?? [];

    selectedNormalVariant = normalVariants.isNotEmpty ? normalVariants.first : null;
    if (widget.tableUsers.isNotEmpty) {
      selectedTableUser = widget.tableUsers.first;
    }
    _currentQuantity = widget.initialQuantity > 0 ? widget.initialQuantity : 1;
  }

  void _incrementQuantity() {
    setState(() {
      _currentQuantity++;
    });
  }

  void _decrementQuantity() {
    setState(() {
      if (_currentQuantity > 1) {
        _currentQuantity--;
      }
    });
  }

  Widget _buildVariantImage(MenuItemVariant variant, {double size = 40}) {
    String? url;
    if (variant.image.isNotEmpty) {
      url = variant.image.startsWith('http')
          ? variant.image
          : '${ApiService.baseUrl}${variant.image}';
    }
    return buildImage(url, Icons.image_not_supported, size);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.95),
              Colors.blue.shade400.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.variantSelectionDialogTitle(widget.item.name),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                if (widget.tableUsers.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: selectedTableUser,
                    decoration: InputDecoration(
                      labelText: l10n.variantSelectionDialogTableOwnerLabel,
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white54), borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Colors.blue.shade800,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    items: widget.tableUsers.map<DropdownMenuItem<String>>((user) {
                      return DropdownMenuItem<String>(
                        value: user,
                        child: Text(user, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedTableUser = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.variantSelectionDialogTableOwnerValidator;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                if (normalVariants.isNotEmpty)
                  DropdownButtonFormField<MenuItemVariant>(
                    value: selectedNormalVariant,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.variantSelectionDialogVariantLabel,
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white54), borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    dropdownColor: Colors.blue.shade900,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    items: normalVariants.map((variant) {
                      return DropdownMenuItem<MenuItemVariant>(
                        value: variant,
                        child: Row(
                          children: [
                            _buildVariantImage(variant, size: 24),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${variant.name} (${CurrencyFormatter.format(variant.price)})', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white),)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newVariant) {
                      setState(() {
                        selectedNormalVariant = newVariant;
                      });
                    },
                    validator: (value) {
                      if (normalVariants.isNotEmpty && value == null) {
                        return l10n.variantSelectionDialogVariantValidator;
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 16),

                if (extraVariants.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.variantSelectionDialogExtrasLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: extraVariants.map((variant) {
                      final isSelected = selectedExtras.contains(variant);
                      return ChoiceChip(
                        backgroundColor: Colors.black.withOpacity(0.2),
                        selectedColor: Colors.white,
                        label: Text(
                          '${variant.name} (+${CurrencyFormatter.format(variant.price)})',
                          style: TextStyle(
                            color: isSelected ? Colors.blue.shade900 : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        avatar: _buildVariantImage(variant, size: 20),
                        selected: isSelected,
                        shape: isSelected
                            ? StadiumBorder(side: BorderSide(color: Colors.yellow.shade700, width: 2))
                            : StadiumBorder(side: BorderSide(color: Colors.white.withOpacity(0.5))),
                        showCheckmark: false,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedExtras.add(variant);
                            } else {
                              selectedExtras.remove(variant);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                      onPressed: _decrementQuantity,
                      tooltip: l10n.tooltipDecrement,
                    ),
                    Text(
                      l10n.variantSelectionDialogQuantity(_currentQuantity.toString()),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                      onPressed: _incrementQuantity,
                      tooltip: l10n.tooltipIncrement,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // *** BURADA DEĞİŞİKLİK: Row yerine Flexible ile düzenlenmiş düzen ***
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.dialogButtonCancel),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          foregroundColor: Colors.blue.shade900,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            widget.onItemSelected(widget.item, selectedNormalVariant, selectedExtras, selectedTableUser, _currentQuantity);
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          l10n.variantSelectionDialogAddToCartButton, 
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
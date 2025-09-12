// lib/widgets/setup_wizard/menu_items/dialogs/variant_edit_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../models/menu_item_variant.dart';
import '../../../../models/template_models/variant_template.dart';

class VariantEditDialog extends StatefulWidget {
  final MenuItemVariant? existingVariant;
  final VariantTemplate? fromTemplate;

  const VariantEditDialog({
    Key? key,
    this.existingVariant,
    this.fromTemplate,
  }) : super(key: key);

  @override
  _VariantEditDialogState createState() => _VariantEditDialogState();
}

class _VariantEditDialogState extends State<VariantEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late bool _isExtra;

  @override
  void initState() {
    super.initState();
    
    // Initialize from existing variant or template
    if (widget.existingVariant != null) {
      _nameController = TextEditingController(text: widget.existingVariant!.name);
      _priceController = TextEditingController(text: widget.existingVariant!.price.toStringAsFixed(2));
      _isExtra = widget.existingVariant!.isExtra;
    } else if (widget.fromTemplate != null) {
      _nameController = TextEditingController(text: widget.fromTemplate!.name);
      // Calculate price based on template multiplier (you might want to get base price from parent)
      final basePrice = 10.0; // Default base price - you should pass this from parent
      final calculatedPrice = basePrice * widget.fromTemplate!.priceMultiplier;
      _priceController = TextEditingController(text: calculatedPrice.toStringAsFixed(2));
      _isExtra = widget.fromTemplate!.isExtra;
    } else {
      _nameController = TextEditingController();
      _priceController = TextEditingController(text: '0.00');
      _isExtra = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }
  
  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final newVariant = MenuItemVariant(
        id: widget.existingVariant?.id ?? -DateTime.now().millisecondsSinceEpoch, // Temporary ID for new variants
        menuItem: widget.existingVariant?.menuItem ?? 0,
        name: _nameController.text.trim(),
        price: double.tryParse(_priceController.text.trim().replaceAll(',', '.')) ?? 0.0,
        isExtra: _isExtra,
        image: widget.existingVariant?.image ?? '',
      );
      Navigator.of(context).pop(newVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.existingVariant == null ? 'Varyant Ekle' : 'Varyant Düzenle'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.variantNameLabel),
              validator: (v) => (v == null || v.isEmpty) ? l10n.validatorRequiredField : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: l10n.variantPriceLabel,
                prefixText: '₺ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return l10n.validatorRequiredField;
                if (double.tryParse(v.replaceAll(',', '.')) == null) return l10n.validatorInvalidNumber;
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(l10n.variantIsExtraLabel),
              subtitle: Text(
                'Bu seçenek ek ücretli bir özellik mi?',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              value: _isExtra,
              onChanged: (val) => setState(() => _isExtra = val),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dialogButtonCancel),
        ),
        ElevatedButton(
          onPressed: _onSave,
          child: Text(l10n.buttonSave),
        ),
      ],
    );
  }
}
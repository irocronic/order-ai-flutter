// lib/widgets/setup_wizard/menu_items/dialogs/custom_product_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CustomProductDialog extends StatefulWidget {
  final String token;
  final int businessId;
  final int targetCategoryId;
  final String selectedCategoryName;

  const CustomProductDialog({
    Key? key,
    required this.token,
    required this.businessId,
    required this.targetCategoryId,
    required this.selectedCategoryName,
  }) : super(key: key);

  @override
  State<CustomProductDialog> createState() => _CustomProductDialogState();
}

class _CustomProductDialogState extends State<CustomProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _productNameController.dispose();
    super.dispose();
  }

  void _onConfirm() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final productName = _productNameController.text.trim();
    
    if (productName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.productNameRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Basit özel ürün verisi hazırla - varsayılan olarak reçeteli
      final customProductData = {
        'templateId': -DateTime.now().millisecondsSinceEpoch, // Negatif ID ile custom ürün
        'productName': productName,
        'isFromRecipe': true, // ✅ Varsayılan olarak reçeteli
        'price': null, // ✅ Reçeteli olduğu için fiyat yok
        'variants': <dynamic>[], // ✅ Başlangıçta varyant yok
        'isCustomProduct': true,
      };

      await Future.delayed(const Duration(milliseconds: 500)); // UX için kısa bekleme

      if (mounted) {
        Navigator.of(context).pop(customProductData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.genericError(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add_circle_outline, 
                      color: Colors.green.shade700, 
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.addNewProductTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          widget.selectedCategoryName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Bilgi kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.quickAddProductTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.quickAddProductInfo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ürün adı girişi
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _productNameController,
                  decoration: InputDecoration(
                    labelText: l10n.productNameLabel,
                    hintText: l10n.productNameHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.fastfood_outlined),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green.shade500),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.productNameRequired : null,
                  enabled: !_isCreating,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _onConfirm(),
                ),
              ),
              const SizedBox(height: 24),

              // Butonlar
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        l10n.dialogButtonCancel,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isCreating ? null : _onConfirm,
                      icon: _isCreating 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.add_circle_outline, size: 20),
                      label: Text(
                        _isCreating ? l10n.addingButtonLabel : l10n.addProductButtonLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: _isCreating ? 0 : 2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
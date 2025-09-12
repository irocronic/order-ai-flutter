// lib/widgets/setup_wizard/menu_items/dialogs/template_variant_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../models/menu_item_variant.dart';
import '../models/variant_template_config.dart';
import '../components/image_picker_widget.dart';

class TemplateVariantForm extends StatefulWidget {
  final VariantTemplateConfig config;
  final VoidCallback onVariantAdded;
  final Function(String, {bool isError}) onMessageChanged;

  const TemplateVariantForm({
    Key? key,
    required this.config,
    required this.onVariantAdded,
    required this.onMessageChanged,
  }) : super(key: key);

  @override
  State<TemplateVariantForm> createState() => _TemplateVariantFormState();
}

class _TemplateVariantFormState extends State<TemplateVariantForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header - Varyant başlığı
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Varyant Ekle - ${widget.config.templateName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  if (widget.config.variants.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.config.variants.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded form content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Mevcut varyantları göster
                  if (widget.config.variants.isNotEmpty) ...[
                    _buildExistingVariants(l10n),
                    const SizedBox(height: 12),
                  ],
                  
                  // Yeni varyant ekleme formu
                  _buildVariantForm(l10n),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingVariants(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eklenen Varyantlar:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 6),
          ...widget.config.variants.map((variant) => Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${variant.name} - ₺${variant.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (variant.isExtra)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ekstra',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      widget.config.removeVariant(variant.id);
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildVariantForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Varyant adı
          TextFormField(
            controller: widget.config.variantNameController,
            decoration: InputDecoration(
              labelText: 'Varyant Adı',
              hintText: 'Örn: Büyük, Küçük, Ekstra Peynir',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            validator: (v) => (v == null || v.isEmpty) ? 'Varyant adı gerekli' : null,
          ),
          const SizedBox(height: 8),
          
          // Varyant fiyatı
          TextFormField(
            controller: widget.config.variantPriceController,
            decoration: InputDecoration(
              labelText: 'Varyant Fiyatı',
              hintText: 'Örn: 5.50',
              prefixText: '₺ ',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Fiyat gerekli';
              if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Geçersiz fiyat';
              return null;
            },
          ),
          const SizedBox(height: 8),
          
          // Ekstra seçeneği
          SwitchListTile(
            title: const Text(
              'Ekstra Seçenek',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Bu seçenek ek ücretli bir özellik mi?',
              style: TextStyle(fontSize: 10),
            ),
            value: widget.config.isVariantExtra,
            onChanged: (val) => setState(() => widget.config.isVariantExtra = val),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 8),
          
          // Varyant görseli
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ImagePickerWidget(
              onImageChanged: (imageFile, imageBytes) {
                widget.config.setVariantImage(imageFile, imageBytes);
              },
              isCompact: true,
            ),
          ),
          const SizedBox(height: 12),
          
          // Varyant ekle butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Varyant Ekle',
                style: TextStyle(fontSize: 12),
              ),
              onPressed: _addVariant,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addVariant() {
    if (!_formKey.currentState!.validate()) return;

    final newVariant = MenuItemVariant(
      id: -DateTime.now().millisecondsSinceEpoch, // Geçici ID
      menuItem: 0, // Template için geçici
      name: widget.config.variantName,
      price: widget.config.variantPrice,
      isExtra: widget.config.isVariantExtra,
      image: '', // Görseller daha sonra upload edilecek
    );

    setState(() {
      widget.config.addVariant(newVariant);
      widget.config.clearVariantForm();
    });

    widget.onVariantAdded();
    widget.onMessageChanged('Varyant "${newVariant.name}" eklendi');
  }
}
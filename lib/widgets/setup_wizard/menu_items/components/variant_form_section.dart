// lib/widgets/setup_wizard/menu_items/components/variant_form_section.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class VariantFormSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final bool isExtraFlag;
  final bool isSubmitting;
  final Function(bool) onExtraFlagChanged;
  final VoidCallback onPickImage;
  final XFile? pickedImageXFile;
  final Uint8List? webImageBytes;

  const VariantFormSection({
    Key? key,
    required this.nameController,
    required this.priceController,
    required this.isExtraFlag,
    required this.isSubmitting,
    required this.onExtraFlagChanged,
    required this.onPickImage,
    this.pickedImageXFile,
    this.webImageBytes,
  }) : super(key: key);

  Widget _buildImagePreview() {
    Widget placeholder = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(
        Icons.add_photo_alternate_outlined, 
        color: Colors.grey.shade500, 
        size: 24
      ),
    );

    if (kIsWeb && webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          webImageBytes!, 
          height: 60, 
          width: 60, 
          fit: BoxFit.cover
        ),
      );
    } else if (!kIsWeb && pickedImageXFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(pickedImageXFile!.path), 
          height: 60, 
          width: 60, 
          fit: BoxFit.cover
        ),
      );
    }
    
    return placeholder;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Varyant adı ve fiyat
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.menuItemVariantsDialogVariantNameLabel,
                  hintText: l10n.menuItemVariantsDialogVariantNameHint,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, 
                    vertical: 16
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) 
                    ? l10n.menuItemVariantsDialogVariantNameRequired 
                    : null,
                enabled: !isSubmitting,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: priceController,
                decoration: InputDecoration(
                  labelText: l10n.menuItemVariantsDialogPriceLabel,
                  prefixText: '₺',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, 
                    vertical: 16
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*[\.,]?\d{0,2}')
                  )
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.menuItemVariantsDialogPriceRequired;
                  if (double.tryParse(v.replaceAll(',', '.')) == null) {
                    return l10n.menuItemVariantsDialogInvalidPrice;
                  }
                  return null;
                },
                enabled: !isSubmitting,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Seçenekler
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: Text(l10n.menuItemVariantsDialogExtraOptionTitle),
                subtitle: Text(l10n.menuItemVariantsDialogExtraOptionSubtitle),
                value: isExtraFlag,
                onChanged: isSubmitting 
                    ? null 
                    : (val) => onExtraFlagChanged(val ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Fotoğraf yükleme alanı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.camera_alt, 
                    color: Colors.blue.shade700, 
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.menuItemVariantsDialogVariantPhotoOptional,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildImagePreview(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(
                          color: Colors.blue.withOpacity(0.3)
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12
                        ),
                      ),
                      onPressed: isSubmitting ? null : onPickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l10n.menuItemVariantsDialogSelectImage),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
// lib/widgets/setup_wizard/menu_items/dialogs/variant_management_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../models/menu_item_variant.dart';
import '../../../../services/firebase_storage_service.dart';
import '../../../../utils/currency_formatter.dart'; // YENİ EKLENEN
import '../models/variant_template_config.dart';
import '../components/image_picker_widget.dart';
import '../utils/icon_utils.dart';

class VariantManagementDialog extends StatefulWidget {
  final int templateId;
  final VariantTemplateConfig variantConfig;
  final List<dynamic> variantTemplates;
  final bool isLoadingVariantTemplates;
  final int businessId;
  final Function(Map<String, dynamic>) onVariantTemplateSelected;

  const VariantManagementDialog({
    Key? key,
    required this.templateId,
    required this.variantConfig,
    required this.variantTemplates,
    required this.isLoadingVariantTemplates,
    required this.businessId,
    required this.onVariantTemplateSelected,
  }) : super(key: key);

  @override
  State<VariantManagementDialog> createState() => _VariantManagementDialogState();
}

class _VariantManagementDialogState extends State<VariantManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;

  void _addVariant() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final variantName = widget.variantConfig.variantNameController.text.trim();
    final priceText = widget.variantConfig.variantPriceController.text.trim();
    
    if (variantName.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.snackbarVariantNameAndPriceRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final price = double.tryParse(priceText.replaceAll(',', '.'));
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.snackbarInvalidPrice),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fotoğraf zorunlu kontrolü
    if (widget.variantConfig.hasVariantImageEnabled && !widget.variantConfig.hasVariantImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.snackbarVariantPhotoRequiredWhenActive),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fotoğraf varsa hemen upload et
    String variantImageUrl = '';
    if (widget.variantConfig.hasVariantImageEnabled && widget.variantConfig.hasVariantImage) {
      try {
        setState(() => _isUploading = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(l10n.snackbarUploadingVariantPhoto),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );

        variantImageUrl = await _uploadVariantImageNow(variantName);
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        print('✅ Varyant fotoğrafı başarıyla upload edildi: $variantImageUrl');
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarPhotoUploadFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isUploading = false);
        return;
      } finally {
        setState(() => _isUploading = false);
      }
    }

    final newVariant = MenuItemVariant(
      id: -DateTime.now().millisecondsSinceEpoch - widget.variantConfig.variants.length,
      menuItem: 0,
      name: variantName,
      price: price,
      isExtra: widget.variantConfig.isVariantExtra,
      image: variantImageUrl,
    );

    setState(() {
      widget.variantConfig.addVariant(newVariant);
      widget.variantConfig.clearVariantForm();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.snackbarVariantAdded(variantName)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String> _uploadVariantImageNow(String variantName) async {
    String fileName;
    if (widget.variantConfig.variantImageXFile != null) {
      fileName = p.basename(widget.variantConfig.variantImageXFile!.path);
    } else {
      final safeVariantName = variantName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      fileName = 'variant_${safeVariantName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    
    String firebaseFileName = "business_${widget.businessId}/variants/${DateTime.now().millisecondsSinceEpoch}_$fileName";
    
    final imageUrl = await FirebaseStorageService.uploadImage(
      imageFile: widget.variantConfig.variantImageXFile != null 
          ? File(widget.variantConfig.variantImageXFile!.path) 
          : null,
      imageBytes: widget.variantConfig.variantWebImageBytes,
      fileName: firebaseFileName,
      folderPath: 'variant_images',
    );
    
    if (imageUrl == null) {
      throw Exception(AppLocalizations.of(context)!.firebaseUploadFailed);
    }
    
    return imageUrl;
  }

  void _removeVariant(int variantId) {
    setState(() {
      widget.variantConfig.removeVariant(variantId);
    });
  }

  void _toggleVariantExtra(bool isExtra) {
    setState(() {
      widget.variantConfig.isVariantExtra = isExtra;
    });
  }

  void _toggleVariantPhoto(bool hasPhoto) {
    setState(() {
      widget.variantConfig.hasVariantImageEnabled = hasPhoto;
      if (!hasPhoto) {
        widget.variantConfig.setVariantImage(null, null);
      }
    });
  }

  bool get _hasUnfinishedVariantData {
    final nameText = widget.variantConfig.variantNameController.text.trim();
    final priceText = widget.variantConfig.variantPriceController.text.trim();
    return nameText.isNotEmpty || priceText.isNotEmpty;
  }

  void _onCompletePressed() {
    if (_hasUnfinishedVariantData) {
      _showUnfinishedVariantWarning();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _showUnfinishedVariantWarning() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                l10n.dialogPendingVariantTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dialogPendingVariantContent1,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.variantConfig.variantNameController.text.trim().isNotEmpty)
                        Text(
                          l10n.dialogPendingVariantContentName(widget.variantConfig.variantNameController.text.trim()),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      if (widget.variantConfig.variantPriceController.text.trim().isNotEmpty)
                        Text(
                          l10n.dialogPendingVariantContentPrice(widget.variantConfig.variantPriceController.text.trim()),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.dialogPendingVariantContent2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.dialogButtonCancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                setState(() {
                  widget.variantConfig.clearVariantForm();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.snackbarPendingVariantDataCleared),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                l10n.dialogButtonDeleteAndExit,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                _addVariant(); // Varyantı ekle
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.buttonAddVariant),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // YENİ EKLENEN: Dinamik para birimi simgesi
    final currencySymbol = CurrencyFormatter.currentSymbol;
    
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.variantManagementDialogTitle(widget.variantConfig.templateName),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isUploading ? null : () {
                    if (_hasUnfinishedVariantData) {
                      _showUnfinishedVariantWarning();
                    } else {
                      Navigator.of(context).pop(true);
                    }
                  },
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hızlı Varyant Ekleme
                    if (widget.variantTemplates.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.flash_on, color: Colors.yellow.shade700, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            l10n.quickAddVariantTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          if (widget.isLoadingVariantTemplates) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.isLoadingVariantTemplates)
                        Container(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            l10n.loadingVariantTemplates,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: widget.variantTemplates.take(12).map<Widget>((variantTemplate) {
                            final variantName = variantTemplate['name'] as String;
                            final isUsed = widget.variantConfig.variants.any((variant) => 
                              variant.name.toLowerCase() == variantName.toLowerCase()
                            );
                            
                            return ActionChip(
                              avatar: Icon(
                                IconUtils.getIconFromName(variantTemplate['icon_name'] ?? 'label_outline'),
                                size: 16,
                                color: isUsed ? Colors.grey : Colors.blue.shade700,
                              ),
                              label: Text(
                                variantName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isUsed ? Colors.grey : Colors.blue.shade700,
                                ),
                              ),
                              backgroundColor: isUsed ? Colors.grey.shade200 : Colors.white,
                              onPressed: isUsed || _isUploading ? null : () {
                                widget.onVariantTemplateSelected(variantTemplate);
                              },
                              elevation: isUsed ? 0 : 2,
                              pressElevation: 1,
                              side: BorderSide(
                                color: isUsed ? Colors.grey.shade300 : Colors.blue.shade300,
                                width: 1,
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                    
                    // Mevcut Varyantlar
                    if (widget.variantConfig.variants.isNotEmpty) ...[
                      Text(
                        l10n.addedVariantsTitle(widget.variantConfig.variants.length),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...widget.variantConfig.variants.map((variant) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    variant.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        // GÜNCELLENDİ: Dinamik para birimi simgesi kullanıldı
                                        '$currencySymbol${variant.price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      if (variant.isExtra) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            l10n.variantExtraTag,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (variant.image.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.camera_alt, color: Colors.blue.shade600, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                l10n.variantWithPhotoTag,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _isUploading ? null : () => _removeVariant(variant.id),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                    
                    // Manuel Varyant Ekleme Formu
                    Text(
                      l10n.manualAddVariantTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Varyant adı ve fiyat
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: widget.variantConfig.variantNameController,
                                  decoration: InputDecoration(
                                    labelText: l10n.variantNameLabel,
                                    hintText: l10n.variantNameHint,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? l10n.validatorVariantNameRequired : null,
                                  enabled: !_isUploading,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: widget.variantConfig.variantPriceController,
                                  decoration: InputDecoration(
                                    labelText: l10n.variantPriceLabel,
                                    // GÜNCELLENDİ: Dinamik para birimi simgesi kullanıldı
                                    prefixText: currencySymbol,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))
                                  ],
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return l10n.validatorPriceRequired;
                                    if (double.tryParse(v.replaceAll(',', '.')) == null) return l10n.validatorInvalidPrice;
                                    return null;
                                  },
                                  enabled: !_isUploading,
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
                                  title: Text(l10n.checkboxExtraOptionTitle),
                                  subtitle: Text(l10n.checkboxExtraOptionSubtitle),
                                  value: widget.variantConfig.isVariantExtra,
                                  onChanged: _isUploading ? null : (val) => _toggleVariantExtra(val ?? false),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  title: Text(l10n.checkboxAddPhotoTitle),
                                  subtitle: Text(l10n.checkboxAddPhotoSubtitle),
                                  value: widget.variantConfig.hasVariantImageEnabled,
                                  onChanged: _isUploading ? null : (val) => _toggleVariantPhoto(val ?? false),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                          
                          // Fotoğraf yükleme alanı
                          if (widget.variantConfig.hasVariantImageEnabled) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.camera_alt, color: Colors.orange.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.variantPhotoTitle,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (widget.variantConfig.hasVariantImage)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            l10n.statusSelected,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Stack(
                                    children: [
                                      ImagePickerWidget(
                                        isCompact: false,
                                        initialImageFile: widget.variantConfig.variantImageXFile,
                                        initialImageBytes: widget.variantConfig.variantWebImageBytes,
                                        onImageChanged: _isUploading 
                                            ? (xFile, bytes) {}
                                            : (xFile, bytes) {
                                                setState(() {
                                                  widget.variantConfig.setVariantImage(xFile, bytes);
                                                });
                                              },
                                      ),
                                      if (_isUploading)
                                        Container(
                                          width: double.infinity,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 20),
                          
                          // Ekle butonu
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isUploading ? null : _addVariant,
                              icon: _isUploading 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.add, size: 20),
                              label: Text(_isUploading ? l10n.statusUploading : l10n.buttonAddVariant),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isUploading ? Colors.grey : Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isUploading ? null : () {
                      if (_hasUnfinishedVariantData) {
                        _showUnfinishedVariantWarning();
                      } else {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: Text(l10n.buttonClose),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _onCompletePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isUploading ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      l10n.buttonComplete(widget.variantConfig.variants.length),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
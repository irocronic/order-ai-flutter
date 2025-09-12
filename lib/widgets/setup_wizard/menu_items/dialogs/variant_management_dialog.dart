// lib/widgets/setup_wizard/menu_items/dialogs/variant_management_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../../../models/menu_item_variant.dart';
import '../../../../services/firebase_storage_service.dart';
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
    if (!_formKey.currentState!.validate()) return;

    final variantName = widget.variantConfig.variantNameController.text.trim();
    final priceText = widget.variantConfig.variantPriceController.text.trim();
    
    if (variantName.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Varyant adı ve fiyat gerekli'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final price = double.tryParse(priceText.replaceAll(',', '.'));
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir fiyat giriniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fotoğraf zorunlu kontrolü
    if (widget.variantConfig.hasVariantImageEnabled && !widget.variantConfig.hasVariantImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf aktif olduğunda varyant fotoğrafı zorunludur'),
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
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Varyant fotoğrafı yükleniyor...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );

        variantImageUrl = await _uploadVariantImageNow(variantName);
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        print('✅ Varyant fotoğrafı başarıyla upload edildi: $variantImageUrl');
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf yüklenemedi: $e'),
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
        content: Text('Varyant "$variantName" eklendi'),
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
      throw Exception('Firebase upload başarısız');
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

  // ✅ YENİ EKLENEN: Bekleyen varyant verisi kontrolü
  bool get _hasUnfinishedVariantData {
    final nameText = widget.variantConfig.variantNameController.text.trim();
    final priceText = widget.variantConfig.variantPriceController.text.trim();
    return nameText.isNotEmpty || priceText.isNotEmpty;
  }

  // ✅ YENİ EKLENEN: Tamamla butonuna basıldığında kontrol
  void _onCompletePressed() {
    if (_hasUnfinishedVariantData) {
      _showUnfinishedVariantWarning();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  // ✅ YENİ EKLENEN: Bekleyen varyant uyarı dialog'u
  void _showUnfinishedVariantWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Bekleyen Varyant',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manuel varyant ekleme formunda doldurulmuş alanlar var.',
                style: TextStyle(fontSize: 16),
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
                        '• Varyant Adı: "${widget.variantConfig.variantNameController.text.trim()}"',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    if (widget.variantConfig.variantPriceController.text.trim().isNotEmpty)
                      Text(
                        '• Fiyat: "₺${widget.variantConfig.variantPriceController.text.trim()}"',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bu varyantı eklemeden çıkmak istiyor musunuz?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                // Form verilerini temizle
                setState(() {
                  widget.variantConfig.clearVariantForm();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bekleyen varyant verileri temizlendi'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Sil ve Çık',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog'u kapat
                _addVariant(); // Varyantı ekle
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Varyant Ekle'),
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
                    'Varyant Yönetimi - ${widget.variantConfig.templateName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isUploading ? null : () {
                    // ✅ YENİ: Close butonunda da kontrol yap
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
                            'Hızlı Varyant Ekle:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          if (widget.isLoadingVariantTemplates) ...[
                            const SizedBox(width: 8),
                            SizedBox(
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
                            'Varyant şablonları yükleniyor...',
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
                        'Eklenen Varyantlar (${widget.variantConfig.variants.length}):',
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
                                        '₺${variant.price.toStringAsFixed(2)}',
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
                                            'Ekstra',
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
                                                'Fotoğraflı',
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
                      'Manuel Varyant Ekle:',
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
                                  decoration: const InputDecoration(
                                    labelText: 'Varyant Adı',
                                    hintText: 'Büyük, Küçük...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Varyant adı gerekli' : null,
                                  enabled: !_isUploading,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: widget.variantConfig.variantPriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Fiyat',
                                    prefixText: '₺',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))
                                  ],
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Fiyat gerekli';
                                    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Geçersiz fiyat';
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
                                  title: const Text('Ekstra seçenek'),
                                  subtitle: const Text('Ek ücretli özellik mi?'),
                                  value: widget.variantConfig.isVariantExtra,
                                  onChanged: _isUploading ? null : (val) => _toggleVariantExtra(val ?? false),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              Expanded(
                                child: CheckboxListTile(
                                  title: const Text('Fotoğraf ekle'),
                                  subtitle: const Text('Varyant görseli'),
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
                                        'Varyant Fotoğrafı',
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
                                            '✓ Seçildi',
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
                                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.add, size: 20),
                              label: Text(_isUploading ? 'Yükleniyor...' : 'Varyant Ekle'),
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
                      // ✅ YENİ: Kapat butonunda da kontrol yap
                      if (_hasUnfinishedVariantData) {
                        _showUnfinishedVariantWarning();
                      } else {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text('Kapat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _onCompletePressed, // ✅ YENİ: Kontrol fonksiyonu
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isUploading ? Colors.grey : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Tamamla (${widget.variantConfig.variants.length})',
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
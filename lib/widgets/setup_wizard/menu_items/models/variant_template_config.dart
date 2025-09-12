// lib/widgets/setup_wizard/menu_items/models/variant_template_config.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../models/menu_item_variant.dart';

class VariantTemplateConfig {
  final int templateId;
  final String templateName;
  List<MenuItemVariant> variants;
  XFile? variantImageXFile;
  Uint8List? variantWebImageBytes;
  final TextEditingController variantNameController;
  final TextEditingController variantPriceController;
  bool isVariantExtra;
  
  // YENİ: Fotoğraf özelliği için state
  bool hasVariantImageEnabled;

  VariantTemplateConfig({
    required this.templateId,
    required this.templateName,
    this.variants = const [],
    this.hasVariantImageEnabled = false,
  }) : 
    variantNameController = TextEditingController(),
    variantPriceController = TextEditingController(),
    isVariantExtra = false;

  void setVariantImage(XFile? imageFile, Uint8List? imageBytes) {
    variantImageXFile = imageFile;
    variantWebImageBytes = imageBytes;
  }

  void addVariant(MenuItemVariant variant) {
    variants = [...variants, variant];
  }

  void removeVariant(int variantId) {
    variants = variants.where((v) => v.id != variantId).toList();
  }

  void clearVariantForm() {
    variantNameController.clear();
    variantPriceController.clear();
    isVariantExtra = false;
    // YENİ: Fotoğraf temizleme - sadece form temizlerken, enable durumunu koruyoruz
    variantImageXFile = null;
    variantWebImageBytes = null;
  }
  
  // YENİ: Fotoğraf tamamen temizleme (enable durumu da dahil)
  void clearVariantImageCompletely() {
    variantImageXFile = null;
    variantWebImageBytes = null;
    hasVariantImageEnabled = false;
  }
  
  // YENİ: Fotoğraf enable/disable toggle
  void toggleVariantImageEnabled() {
    hasVariantImageEnabled = !hasVariantImageEnabled;
    if (!hasVariantImageEnabled) {
      // Kapatılırsa fotoğrafı da temizle
      variantImageXFile = null;
      variantWebImageBytes = null;
    }
  }

  void dispose() {
    variantNameController.dispose();
    variantPriceController.dispose();
  }

  bool get hasVariantImage => variantImageXFile != null || variantWebImageBytes != null;
  String get variantName => variantNameController.text.trim();
  double get variantPrice => double.tryParse(variantPriceController.text.trim().replaceAll(',', '.')) ?? 0.0;
}
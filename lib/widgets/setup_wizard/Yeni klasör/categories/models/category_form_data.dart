// lib/widgets/setup_wizard/categories/models/category_form_data.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CategoryFormData {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController kdvController = TextEditingController(text: '10.0');
  
  dynamic selectedParentCategory;
  int? selectedKdsScreenId;
  XFile? pickedImageXFile;
  Uint8List? webImageBytes;

  void setImage(XFile? imageFile, Uint8List? imageBytes) {
    pickedImageXFile = imageFile;
    webImageBytes = imageBytes;
  }

  void clear() {
    nameController.clear();
    kdvController.text = '10.0';
    selectedParentCategory = null;
    selectedKdsScreenId = null;
    pickedImageXFile = null;
    webImageBytes = null;
  }

  void dispose() {
    nameController.dispose();
    kdvController.dispose();
  }

  bool get hasImage => pickedImageXFile != null || webImageBytes != null;
  
  String get name => nameController.text.trim();
  double get kdvRate => double.tryParse(kdvController.text.trim().replaceAll(',', '.')) ?? 10.0;
  int? get selectedParentCategoryId => selectedParentCategory?['id'] as int?;
}
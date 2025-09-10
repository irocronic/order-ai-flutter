// lib/widgets/setup_wizard/menu_items/models/menu_item_form_data.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MenuItemFormData {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController kdvController = TextEditingController(text: '10.0');
  
  int? selectedCategoryId;
  XFile? pickedImageXFile;
  Uint8List? webImageBytes;

  void setImage(XFile? imageFile, Uint8List? imageBytes) {
    pickedImageXFile = imageFile;
    webImageBytes = imageBytes;
  }

  void clear() {
    nameController.clear();
    descriptionController.clear();
    kdvController.text = '10.0';
    selectedCategoryId = null;
    pickedImageXFile = null;
    webImageBytes = null;
  }

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    kdvController.dispose();
  }

  bool get hasImage => pickedImageXFile != null || webImageBytes != null;
  
  String get name => nameController.text.trim();
  String get description => descriptionController.text.trim();
  double get kdvRate => double.tryParse(kdvController.text.trim().replaceAll(',', '.')) ?? 10.0;
}
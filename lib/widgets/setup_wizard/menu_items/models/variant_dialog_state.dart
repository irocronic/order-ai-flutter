// lib/widgets/setup_wizard/menu_items/models/variant_dialog_state.dart
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../../../models/menu_item_variant.dart';

class VariantDialogState {
  List<MenuItemVariant> variants = [];
  bool isLoading = true;
  bool isSubmitting = false;
  String message = '';
  String successMessage = '';
  bool isExtraFlag = false;

  XFile? pickedImageXFile;
  Uint8List? webImageBytes;

  // Varyant şablonları
  List<dynamic> variantTemplates = [];
  bool isLoadingTemplates = false;
  bool hasTemplateLoadError = false;
  String templateErrorMessage = '';
}
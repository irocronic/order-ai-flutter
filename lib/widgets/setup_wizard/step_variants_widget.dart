// lib/widgets/setup_wizard/step_variants_widget.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/api_service.dart';
import '../../services/firebase_storage_service.dart';
import '../../models/menu_item.dart';
import '../../models/menu_item_variant.dart';
import '../../services/user_session.dart';
import '../../screens/subscription_screen.dart';


class StepVariantsWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepVariantsWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  StepVariantsWidgetState createState() => StepVariantsWidgetState();
}

class StepVariantsWidgetState extends State<StepVariantsWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _variantNameController = TextEditingController();
  final TextEditingController _variantPriceController = TextEditingController();
  bool _isExtraFlag = false;

  List<MenuItem> menuItems = [];
  
  MenuItem? _selectedMenuItem;
  List<MenuItemVariant> _addedVariants = [];

  bool _isLoadingScreenData = true;
  bool _isSubmittingVariant = false;
  String _message = '';
  String _successMessage = '';

  XFile? _pickedImageXFile;
  Uint8List? _webImageBytes;

  late final AppLocalizations l10n;
  bool _didFetchData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      l10n = AppLocalizations.of(context)!;
      _fetchMenuItems();
      _didFetchData = true;
    }
  }

  @override
  void dispose() {
    _variantNameController.dispose();
    _variantPriceController.dispose();
    super.dispose();
  }

  Future<void> _fetchMenuItems() async {
    if (!mounted) return;
    setState(() {
      _isLoadingScreenData = true;
      _message = '';
      _successMessage = '';
      _selectedMenuItem = null;
      _addedVariants = [];
    });
    try {
      final menuItemsData = await ApiService.fetchMenuItemsForBusiness(widget.token);
      if (mounted) {
        setState(() {
          menuItems = menuItemsData.map((itemJson) => MenuItem.fromJson(itemJson)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        _message = l10n.setupVariantsErrorLoadingMenuItems(e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoadingScreenData = false);
    }
  }

  Future<void> _fetchVariantsForSelectedMenuItem() async {
    if (_selectedMenuItem == null || !mounted) return;
    setState(() {
      _isLoadingScreenData = true;
      _message = '';
      _successMessage = '';
    });
    try {
      final variantsData = await ApiService.fetchVariantsForMenuItem(widget.token, _selectedMenuItem!.id);
      if (mounted) {
        final itemIndex = menuItems.indexWhere((item) => item.id == _selectedMenuItem!.id);
        if (itemIndex != -1) {
          final oldItem = menuItems[itemIndex];
          menuItems[itemIndex] = MenuItem(
            id: oldItem.id,
            name: oldItem.name,
            description: oldItem.description,
            image: oldItem.image,
            category: oldItem.category,
            isCampaignBundle: oldItem.isCampaignBundle,
            price: oldItem.price,
            variants: variantsData.map((v) => MenuItemVariant.fromJson(v)).toList(),
          );
        }
        
        setState(() {
          _addedVariants = variantsData.map((variantJson) => MenuItemVariant.fromJson(variantJson)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        _message = l10n.setupVariantsErrorLoadingVariants(e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoadingScreenData = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      if (kIsWeb) {
        _webImageBytes = await image.readAsBytes();
        _pickedImageXFile = null;
      } else {
        _pickedImageXFile = image;
        _webImageBytes = null;
      }
      if (mounted) setState(() {});
    }
  }

  Widget _buildImagePreview() {
    Widget placeholder = Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white38)),
      child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 30),
    );
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(_webImageBytes!, height: 80, width: 80, fit: BoxFit.cover));
    } else if (!kIsWeb && _pickedImageXFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(_pickedImageXFile!.path), height: 80, width: 80, fit: BoxFit.cover));
    }
    return placeholder;
  }

  void _clearMessagesAfterDelay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && (_successMessage.isNotEmpty || _message.isNotEmpty)) {
        setState(() {
          _successMessage = '';
          _message = '';
        });
      }
    });
  }

  void _showLimitReachedDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogLimitReachedTitle),
        content: Text(message),
        actions: [
          TextButton(
            child: Text(l10n.dialogButtonLater),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text(l10n.dialogButtonUpgradePlan),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addVariant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMenuItem == null) {
      if (mounted) setState(() => _message = l10n.setupVariantsErrorSelectMainProductFirst);
      return;
    }
    if (!mounted) return;

    final int totalVariantCount = menuItems.fold(0, (sum, item) => sum + (item.variants?.length ?? 0));
    final currentLimits = UserSession.limitsNotifier.value;
    if (totalVariantCount >= currentLimits.maxVariants) {
      _showLimitReachedDialog(
        l10n.createVariantErrorLimitExceeded(currentLimits.maxVariants.toString())
      );
      return; 
    }

    setState(() {
      _isSubmittingVariant = true;
      _message = '';
      _successMessage = '';
    });

    String? imageUrl;
    if (_pickedImageXFile != null || _webImageBytes != null) {
      try {
        String fileName = _pickedImageXFile != null
            ? p.basename(_pickedImageXFile!.path)
            : 'variant_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String firebaseFileName =
            "business_${widget.businessId}/menu_items/${_selectedMenuItem!.id}/variants/${DateTime.now().millisecondsSinceEpoch}_$fileName";

        imageUrl = await FirebaseStorageService.uploadImage(
          imageFile: _pickedImageXFile != null ? File(_pickedImageXFile!.path) : null,
          imageBytes: _webImageBytes,
          fileName: firebaseFileName,
          folderPath: 'variant_images',
        );
        if (imageUrl == null) throw Exception(l10n.errorFirebaseUploadFailed);
      } catch (e) {
        if (mounted) {
          setState(() {
            _message = l10n.errorUploadingPhotoGeneral(e.toString());
            _isSubmittingVariant = false;
          });
        }
        return;
      }
    }

    try {
      await ApiService.createMenuItemVariant(
        widget.token,
        _selectedMenuItem!.id,
        _variantNameController.text.trim(),
        double.tryParse(_variantPriceController.text.trim().replaceAll(',', '.')) ?? 0.0,
        _isExtraFlag,
        imageUrl,
      );
      if (mounted) {
        _successMessage = l10n.setupVariantsSuccessAdded(_variantNameController.text.trim());
        _variantNameController.clear();
        _variantPriceController.clear();
        _isExtraFlag = false;
        _pickedImageXFile = null;
        _webImageBytes = null;
        FocusScope.of(context).unfocus();
        await _fetchVariantsForSelectedMenuItem();
      }
    } catch (e) {
      if (mounted) {
        _message = e.toString().replaceFirst("Exception: ", "");
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingVariant = false);
        _clearMessagesAfterDelay();
      }
    }
  }

  Future<void> _deleteVariant(int variantId, String variantName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogDeleteVariantTitle),
        content: Text(l10n.dialogDeleteVariantContent(variantName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.dialogButtonCancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.dialogButtonDelete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoadingScreenData = true);
      try {
        await ApiService.deleteMenuItemVariant(widget.token, variantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.infoVariantDeletedSuccess),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          await _fetchVariantsForSelectedMenuItem();
        }
      } catch (e) {
        if (mounted) {
          setState(() =>
              _message = l10n.errorDeletingVariantGeneral(e.toString().replaceFirst("Exception: ", "")));
        }
      } finally {
        if (mounted) setState(() => _isLoadingScreenData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: Colors.white);
    final inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.white),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.redAccent.shade100),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      prefixIconColor: Colors.white.withOpacity(0.7),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoadingScreenData && menuItems.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(l10n.setupVariantsLoadingMainProducts, style: textStyle)))
          else if (menuItems.isEmpty)
            Center(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(l10n.setupVariantsErrorCreateMainProductFirst,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 16))))
          else
            DropdownButtonFormField<MenuItem>(
              value: _selectedMenuItem,
              style: textStyle,
              dropdownColor: Colors.blue.shade800,
              iconEnabledColor: Colors.white70,
              decoration: inputDecoration.copyWith(
                labelText: l10n.setupVariantsLabelSelectMainProduct,
                prefixIcon: const Icon(Icons.fastfood_rounded),
              ),
              items: menuItems.map<DropdownMenuItem<MenuItem>>((MenuItem item) {
                return DropdownMenuItem<MenuItem>(
                  value: item,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (MenuItem? newValue) {
                setState(() {
                  _selectedMenuItem = newValue;
                  _addedVariants = [];
                  _variantNameController.clear();
                  _variantPriceController.clear();
                  _isExtraFlag = false;
                  _pickedImageXFile = null;
                  _webImageBytes = null;
                  _message = '';
                  _successMessage = '';
                  if (_selectedMenuItem != null) {
                    _fetchVariantsForSelectedMenuItem();
                  }
                });
              },
              validator: (value) => value == null ? l10n.setupVariantsValidatorSelectMainProduct : null,
            ),
          const SizedBox(height: 16),
          if (_selectedMenuItem != null)
            Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.setupVariantsTitleAddNew(_selectedMenuItem!.name),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _variantNameController,
                      style: textStyle,
                      decoration: inputDecoration.copyWith(
                        labelText: l10n.setupVariantsLabelVariantName,
                        prefixIcon: const Icon(Icons.local_offer_outlined),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? l10n.variantNameValidator : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _variantPriceController,
                      style: textStyle,
                      decoration: inputDecoration.copyWith(
                        labelText: l10n.variantPriceLabel,
                          prefixIcon: const Icon(Icons.price_change_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return l10n.variantPriceValidator;
                        final price = double.tryParse(value.trim().replaceAll(',', '.'));
                        if (price == null || price < 0) return l10n.variantPriceValidatorInvalid;
                        return null;
                      },
                    ),
                    SwitchListTile(
                      title: Text(l10n.variantIsExtraLabel, style: textStyle),
                      value: _isExtraFlag,
                      onChanged: (bool value) => setState(() => _isExtraFlag = value),
                      activeColor: Colors.lightBlueAccent,
                      inactiveTrackColor: Colors.white30,
                      contentPadding: EdgeInsets.zero,
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
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.white.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 12)),
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(l10n.setupVariantsLabelSelectImage, textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: _isSubmittingVariant
                          ? const SizedBox.shrink()
                          : const Icon(Icons.add_circle_outline),
                      label: _isSubmittingVariant
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade900))
                          : Text(l10n.buttonAddVariant),
                      onPressed: _isSubmittingVariant ? null : _addVariant,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.95),
                          foregroundColor: Colors.blue.shade900,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    if (_successMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(_successMessage,
                            style: const TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    if (_message.isNotEmpty && !_isLoadingScreenData && !_isSubmittingVariant)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(_message,
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (_selectedMenuItem != null)
            Text(l10n.setupVariantsTitleAddedFor(_selectedMenuItem!.name),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          if (_selectedMenuItem != null) const Divider(color: Colors.white70),
          if (_isLoadingScreenData && _selectedMenuItem != null)
            Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(l10n.setupVariantsLoading, style: textStyle)))
          else if (_selectedMenuItem != null && _addedVariants.isEmpty)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(l10n.setupVariantsNoVariantsForProduct(_selectedMenuItem!.name), style: textStyle, textAlign: TextAlign.center)))
          else if (_selectedMenuItem != null)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addedVariants.length,
                itemBuilder: (context, index) {
                  final variant = _addedVariants[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    color: Colors.white.withOpacity(0.1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: variant.image.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                variant.image.startsWith('http')
                                    ? variant.image
                                    : ApiService.baseUrl + variant.image,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, s) =>
                                    const Icon(Icons.broken_image_outlined, size: 24, color: Colors.white70),
                              ),
                            )
                          : const Icon(Icons.label_important_outline, size: 24, color: Colors.white70),
                      title: Text("${variant.name} ${variant.isExtra ? l10n.variantExtraSuffix : ''}", style: textStyle),
                      subtitle: Text(l10n.variantPriceDisplay(variant.name, variant.price.toStringAsFixed(2), l10n.currencySymbol), style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: l10n.tooltipDelete,
                        onPressed: () => _deleteVariant(variant.id, variant.name),
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
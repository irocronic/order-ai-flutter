// lib/widgets/setup_wizard/step_menu_items_widget.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:collection/collection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/api_service.dart';
import '../../services/firebase_storage_service.dart';
import '../../models/menu_item.dart';
import '../../services/user_session.dart';
import '../../screens/subscription_screen.dart';

class StepMenuItemsWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepMenuItemsWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  StepMenuItemsWidgetState createState() => StepMenuItemsWidgetState();
}

class StepMenuItemsWidgetState extends State<StepMenuItemsWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _kdvController = TextEditingController(text: '10.0');

  int? _selectedCategoryId;
  List<dynamic> _availableCategories = [];
  
  List<MenuItem> addedMenuItems = [];

  bool _isLoadingScreenData = true;
  bool _isSubmittingMenuItem = false;
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
      _fetchInitialData();
      _didFetchData = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _kdvController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingScreenData = true;
      _message = '';
      _successMessage = '';
    });
    try {
      final categoriesData = await ApiService.fetchCategoriesForBusiness(widget.token);
      final menuItemsData = await ApiService.fetchMenuItemsForBusiness(widget.token);

      if (mounted) {
        setState(() {
          _availableCategories = categoriesData;
          addedMenuItems = menuItemsData.map((itemJson) => MenuItem.fromJson(itemJson)).toList();
          if (_selectedCategoryId != null &&
              !_availableCategories.any((cat) => cat['id'] == _selectedCategoryId)) {
            _selectedCategoryId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _message = l10n.errorLoadingInitialData(e.toString().replaceFirst("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoadingScreenData = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
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
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white38),
      ),
      child: const Icon(Icons.add_photo_alternate_outlined,
          color: Colors.white70, size: 40),
    );

    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(_webImageBytes!, height: 100, width: 100, fit: BoxFit.cover),
      );
    } else if (!kIsWeb && _pickedImageXFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(_pickedImageXFile!.path), height: 100, width: 100, fit: BoxFit.cover),
      );
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
  
  void _onCategoryChanged(int? newCategoryId) {
    setState(() {
      _selectedCategoryId = newCategoryId;
      if (newCategoryId != null) {
        final selectedCategory = _availableCategories.firstWhere(
          (cat) => cat['id'] == newCategoryId,
          orElse: () => null,
        );
        if (selectedCategory != null && selectedCategory['kdv_rate'] != null) {
          _kdvController.text = selectedCategory['kdv_rate'].toString();
        } else {
          _kdvController.text = '10.0'; // Default value
        }
      } else {
        _kdvController.text = '10.0'; // Default value
      }
    });
  }

  Future<void> _addMenuItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null && _availableCategories.isNotEmpty) {
      if (mounted) {
        setState(() => _message = l10n.setupMenuItemsErrorSelectCategory);
        _clearMessagesAfterDelay();
      }
      return;
    }
    if (!mounted) return;

    // *** DEĞİŞİKLİK BURADA: Artık `UserSession.limitsNotifier`'dan gelen anlık veriyi kullanıyoruz. ***
    final currentLimits = UserSession.limitsNotifier.value;
    if (addedMenuItems.length >= currentLimits.maxMenuItems) {
        _showLimitReachedDialog(
            l10n.createMenuItemErrorLimitExceeded(currentLimits.maxMenuItems.toString())
        );
        return;
    }

    setState(() {
      _isSubmittingMenuItem = true;
      _message = '';
      _successMessage = '';
    });

    String? imageUrl;
    if (_pickedImageXFile != null || _webImageBytes != null) {
      try {
        String fileName = _pickedImageXFile != null
            ? p.basename(_pickedImageXFile!.path)
            : 'menu_item_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String firebaseFileName =
            "business_${widget.businessId}/menu_items/${DateTime.now().millisecondsSinceEpoch}_$fileName";

        imageUrl = await FirebaseStorageService.uploadImage(
          imageFile: _pickedImageXFile != null ? File(_pickedImageXFile!.path) : null,
          imageBytes: _webImageBytes,
          fileName: firebaseFileName,
          folderPath: 'menu_item_images',
        );
        if (imageUrl == null) throw Exception(l10n.errorFirebaseUploadFailed);
      } catch (e) {
        if (mounted) {
          setState(() {
            _message = l10n.errorUploadingPhotoGeneral(e.toString());
            _isSubmittingMenuItem = false;
          });
        }
        return;
      }
    }

    try {
      await ApiService.createMenuItemForBusiness(
        widget.token,
        widget.businessId,
        _nameController.text.trim(),
        _descriptionController.text.trim(),
        _selectedCategoryId,
        imageUrl,
        double.tryParse(_kdvController.text.trim().replaceAll(',', '.')) ?? 10.0,
      );
      if (mounted) {
        _successMessage = l10n.setupMenuItemsSuccessAdded(_nameController.text.trim());
        _nameController.clear();
        _descriptionController.clear();
        _kdvController.text = '10.0';
        _pickedImageXFile = null;
        _webImageBytes = null;
        FocusScope.of(context).unfocus();
        await _fetchInitialData();
      }
    } catch (e) {
      if (mounted) {
        String rawError = e.toString().replaceFirst("Exception: ", "");
        final jsonStartIndex = rawError.indexOf('{');
        if (jsonStartIndex != -1) {
          try {
            final jsonString = rawError.substring(jsonStartIndex);
            final decodedError = jsonDecode(jsonString);

            if (decodedError is Map && decodedError['code'] == 'limit_reached') {
              _showLimitReachedDialog(decodedError['detail']);
              setState(() => _message = ''); 
            } else {
              setState(() => _message = decodedError['detail'] ?? rawError);
            }
          } catch (jsonError) {
            setState(() => _message = rawError);
          }
        } else {
          setState(() => _message = rawError);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingMenuItem = false);
        _clearMessagesAfterDelay();
      }
    }
  }

  Future<void> _deleteMenuItem(int menuItemId, String menuItemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogDeleteMenuItemTitle),
        content: Text(l10n.dialogDeleteMenuItemContent(menuItemName)),
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
        await ApiService.deleteMenuItem(widget.token, menuItemId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.setupMenuItemsInfoDeleted(menuItemName)),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          await _fetchInitialData();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _message =
              l10n.errorDeletingMenuItemGeneral(e.toString().replaceFirst("Exception: ", "")));
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
          Text(
            l10n.setupMenuItemsDescription,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                 Text(
                  l10n.setupMenuItemsAddButton,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(
                    labelText: l10n.setupMenuItemsNameLabel,
                    prefixIcon: const Icon(Icons.fastfood_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.setupMenuItemsNameValidator
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(
                    labelText: l10n.setupMenuItemsDescriptionLabel,
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _isLoadingScreenData && _availableCategories.isEmpty
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(l10n.setupMenuItemsLoadingCategories, style: textStyle)))
                    : _availableCategories.isEmpty
                        ? Center(
                            child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(l10n.setupMenuItemsErrorCreateCategoryFirst,
                                    style: const TextStyle(color: Colors.orangeAccent))))
                        : DropdownButtonFormField<int?>(
                            value: _selectedCategoryId,
                            style: textStyle,
                            dropdownColor: Colors.blue.shade800,
                            iconEnabledColor: Colors.white70,
                            decoration: inputDecoration.copyWith(
                              labelText: l10n.setupMenuItemsSelectCategoryLabel,
                              prefixIcon: const Icon(Icons.category_outlined),
                            ),
                            items: _availableCategories.map<DropdownMenuItem<int?>>((category) {
                              return DropdownMenuItem<int?>(
                                value: category['id'] as int?,
                                child: Text(category['name'] ?? l10n.unknownCategory),
                              );
                            }).toList(),
                            onChanged: (value) => _onCategoryChanged(value),
                            validator: (value) => value == null
                                ? l10n.setupMenuItemsSelectCategoryValidator
                                : null,
                          ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _kdvController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(
                    labelText: l10n.menuItemKdvRateLabel,
                    suffixText: '%',
                    prefixIcon: const Icon(Icons.percent_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.kdvRateValidatorRequired;
                    }
                    final rate = double.tryParse(value.trim().replaceAll(',', '.'));
                    if (rate == null || rate < 0 || rate > 100) {
                      return l10n.kdvRateValidatorInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                        label: Text(l10n.setupMenuItemsSelectImageLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: _isSubmittingMenuItem
                      ? const SizedBox.shrink()
                      : const Icon(Icons.add_circle_outline),
                  label: _isSubmittingMenuItem
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade900))
                      : Text(l10n.setupMenuItemsAddButton),
                  onPressed: _isSubmittingMenuItem ||
                          (_isLoadingScreenData && _availableCategories.isEmpty)
                      ? null
                      : _addMenuItem,
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
                if (_message.isNotEmpty && !_isLoadingScreenData && !_isSubmittingMenuItem)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(_message,
                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.setupMenuItemsAddedTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Divider(color: Colors.white70),
          _isLoadingScreenData && addedMenuItems.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : addedMenuItems.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(l10n.noMenuItemsAdded, style: textStyle),
                    ))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: addedMenuItems.length,
                      itemBuilder: (context, index) {
                        final menuItem = addedMenuItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          color: Colors.white.withOpacity(0.1),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: menuItem.image.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      menuItem.image.startsWith('http')
                                          ? menuItem.image
                                          : ApiService.baseUrl + menuItem.image,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, o, s) =>
                                          const Icon(Icons.restaurant_menu_outlined, size: 30, color: Colors.white70),
                                    ),
                                  )
                                : const Icon(Icons.restaurant_menu_outlined, size: 30, color: Colors.white70),
                            title: Text(menuItem.name, style: textStyle),
                            subtitle: Text(menuItem.category?['name'] ?? l10n.setupMenuItemsNoCategory, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: l10n.setupMenuItemsDeleteTooltip,
                              onPressed: () => _deleteMenuItem(menuItem.id, menuItem.name),
                            ),
                          ),
                        );
                      },
                    ),
          const SizedBox(height: 10),
          if (!_isLoadingScreenData)
            // === DEĞİŞİKLİK BURADA: Metin, ValueListenableBuilder ile sarmalandı ===
            ValueListenableBuilder<SubscriptionLimits>(
              valueListenable: UserSession.limitsNotifier,
              builder: (context, limits, child) {
                return Text(
                  l10n.setupMenuItemsTotalCreatedWithLimit(addedMenuItems.length.toString(), limits.maxMenuItems.toString()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.8)),
                );
              },
            ),
        ],
      ),
    );
  }
}
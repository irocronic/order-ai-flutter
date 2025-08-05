// lib/widgets/setup_wizard/step_categories_widget.dart

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
import '../../services/kds_management_service.dart';
import '../../models/kds_screen_model.dart';
import '../../services/user_session.dart';
import '../../screens/subscription_screen.dart';

class StepCategoriesWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepCategoriesWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  StepCategoriesWidgetState createState() => StepCategoriesWidgetState();
}

class StepCategoriesWidgetState extends State<StepCategoriesWidget> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _kdvController = TextEditingController(text: '10.0');

  dynamic _selectedParentCategory;
  
  List<dynamic> categories = [];

  List<KdsScreenModel> _availableKdsScreens = [];
  int? _selectedKdsScreenId;

  bool _isLoadingScreenData = true;
  bool _isSubmittingCategory = false;
  
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
      final results = await Future.wait([
        ApiService.fetchCategoriesForBusiness(widget.token),
        KdsManagementService.fetchKdsScreens(widget.token, widget.businessId),
      ]);

      if (mounted) {
        setState(() {
          categories = results[0] as List<dynamic>;
          _availableKdsScreens = (results[1] as List<KdsScreenModel>)
              .where((kds) => kds.isActive)
              .toList();

          if (_availableKdsScreens.length == 1) {
            _selectedKdsScreenId = _availableKdsScreens.first.id;
          } else {
            _selectedKdsScreenId = null;
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
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white38),
      ),
      child: const Icon(Icons.add_a_photo_outlined, color: Colors.white70, size: 40),
    );

    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(_webImageBytes!,
              height: 100, width: 100, fit: BoxFit.cover));
    } else if (!kIsWeb && _pickedImageXFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(_pickedImageXFile!.path),
            height: 100, width: 100, fit: BoxFit.cover));
    }
    return placeholder;
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

  Future<void> _addCategory() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    final currentLimits = UserSession.limitsNotifier.value;
    if (categories.length >= currentLimits.maxCategories) {
        _showLimitReachedDialog(
            l10n.createCategoryErrorLimitExceeded(currentLimits.maxCategories.toString())
        );
        return;
    }

    if (_availableKdsScreens.isNotEmpty && _selectedKdsScreenId == null) {
      setState(() {
        _message = l10n.setupCategoriesErrorSelectKds;
      });
      return;
    }

    setState(() {
      _isSubmittingCategory = true;
      _message = '';
      _successMessage = '';
    });

    String? imageUrl;
    if (_pickedImageXFile != null || _webImageBytes != null) {
      try {
        String fileName = _pickedImageXFile != null
            ? p.basename(_pickedImageXFile!.path)
            : 'category_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String firebaseFileName =
            "business_${widget.businessId}/categories/${DateTime.now().millisecondsSinceEpoch}_$fileName";

        imageUrl = await FirebaseStorageService.uploadImage(
          imageFile:
              _pickedImageXFile != null ? File(_pickedImageXFile!.path) : null,
          imageBytes: _webImageBytes,
          fileName: firebaseFileName,
          folderPath: 'category_images',
        );
        if (imageUrl == null) throw Exception(l10n.errorFirebaseUploadFailed);
      } catch (e) {
        if (mounted) {
          setState(() {
            _message = l10n.errorUploadingPhotoGeneral(e.toString());
            _isSubmittingCategory = false;
          });
        }
        return;
      }
    }

    try {
      await ApiService.createCategoryForBusiness(
        widget.token,
        widget.businessId,
        _nameController.text.trim(),
        _selectedParentCategory?['id'] as int?,
        imageUrl,
        _selectedKdsScreenId,
        double.tryParse(_kdvController.text.trim().replaceAll(',', '.')) ?? 10.0,
      );
      if (mounted) {
        _successMessage =
            l10n.setupCategoriesSuccessAdded(_nameController.text.trim());
        _nameController.clear();
        _kdvController.text = '10.0'; 
        _selectedParentCategory = null;
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
        setState(() => _isSubmittingCategory = false);
        _clearMessagesAfterDelay();
      }
    }
  }

  Future<void> _deleteCategory(int categoryId, String categoryName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogDeleteCategoryTitle),
        content: Text(l10n.setupCategoriesDeleteDialogContent(categoryName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.dialogButtonCancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.dialogButtonDelete,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoadingScreenData = true);
      try {
        await ApiService.deleteCategory(widget.token, categoryId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.setupCategoriesInfoDeleted(categoryName)),
                backgroundColor: Colors.orangeAccent),
          );
          await _fetchInitialData();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _message =
              l10n.setupCategoriesErrorDeleting(e.toString().replaceFirst("Exception: ", "")));
        }
      } finally {
        if (mounted) setState(() => _isLoadingScreenData = false);
      }
    }
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
            l10n.setupCategoriesDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.setupCategoriesAddButton,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    style: textStyle,
                    decoration: inputDecoration.copyWith(
                      labelText: l10n.categoryNameLabelRequired,
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? l10n.categoryNameValidator
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _kdvController,
                    style: textStyle,
                    decoration: inputDecoration.copyWith(
                      labelText: l10n.categoryDefaultKdvRateLabel,
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
                  DropdownButtonFormField<dynamic>(
                    isExpanded: true,
                    value: _selectedParentCategory,
                    style: textStyle,
                    dropdownColor: Colors.blue.shade800,
                    iconEnabledColor: Colors.white70,
                    decoration: inputDecoration.copyWith(
                      labelText: l10n.parentCategoryLabel,
                      prefixIcon: const Icon(Icons.account_tree_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(l10n.setupCategoriesMainCategory, style: textStyle)),
                      ...categories
                          .where((cat) => cat['parent'] == null)
                          .map<DropdownMenuItem<dynamic>>((category) {
                        return DropdownMenuItem<dynamic>(
                          value: category,
                          child: Text(
                              category['name'] ?? l10n.unknownCategory,
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedParentCategory = value),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingScreenData && _availableKdsScreens.isEmpty)
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(l10n.setupCategoriesKdsLoading, style: textStyle)))
                  else if (_availableKdsScreens.isEmpty)
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                                l10n.setupCategoriesErrorDefineKdsFirst,
                                style: const TextStyle(color: Colors.orangeAccent))))
                  else
                    DropdownButtonFormField<int?>(
                      isExpanded: true,
                      value: _selectedKdsScreenId,
                      style: textStyle,
                      dropdownColor: Colors.blue.shade800,
                      iconEnabledColor: Colors.white70,
                      decoration: inputDecoration.copyWith(
                        labelText: l10n.setupCategoriesLabelDisplayKds,
                        prefixIcon: const Icon(Icons.monitor),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                                l10n.setupCategoriesHintSelectKds, style: textStyle)),
                        ..._availableKdsScreens
                            .map<DropdownMenuItem<int?>>((kds) {
                          return DropdownMenuItem<int?>(
                            value: kds.id,
                            child: Text(kds.name,
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ],
                      validator: (value) {
                        if (_availableKdsScreens.isNotEmpty &&
                            value == null) {
                          return l10n.setupCategoriesValidatorSelectKds;
                        }
                        return null;
                      },
                      onChanged: (value) =>
                          setState(() => _selectedKdsScreenId = value),
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
                          label: Text(l10n.setupCategoriesSelectImageLabel),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: _isSubmittingCategory
                        ? const SizedBox.shrink()
                        : const Icon(Icons.add_circle_outline),
                    label: _isSubmittingCategory
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.blue.shade900))
                        : Text(l10n.setupCategoriesAddButton),
                    onPressed: _isSubmittingCategory ||
                            (_isLoadingScreenData &&
                                _availableKdsScreens.isEmpty)
                        ? null
                        : _addCategory,
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
                          style: const TextStyle(
                              color: Colors.lightGreenAccent,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  if (_message.isNotEmpty && !_isLoadingScreenData && !_isSubmittingCategory)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(_message,
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.setupCategoriesAddedTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Divider(color: Colors.white70),
          _isLoadingScreenData && categories.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : categories.isEmpty
                  ? Center(child: Text(l10n.noCategoriesAdded, style: textStyle))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        String parentName = "";
                        if (category['parent'] != null) {
                          final parentCat = categories.firstWhereOrNull(
                              (c) => c['id'] == category['parent']);
                          if (parentCat != null) {
                            parentName = l10n.setupCategoriesSubtitleParent(
                                parentCat['name']);
                          }
                        }

                        String kdsInfo = "";
                        if (category['assigned_kds'] != null) {
                          if (category['assigned_kds'] is Map &&
                              category['assigned_kds']['name'] != null) {
                            kdsInfo = l10n.setupCategoriesSubtitleKdsName(
                                category['assigned_kds']['name']);
                          } else if (category['assigned_kds'] is int) {
                            final kdsId = category['assigned_kds'] as int;
                            final kdsScreen = _availableKdsScreens
                                .firstWhereOrNull((kds) => kds.id == kdsId);
                            if (kdsScreen != null) {
                              kdsInfo = l10n.setupCategoriesSubtitleKdsName(
                                  kdsScreen.name);
                            } else {
                              kdsInfo = l10n.setupCategoriesSubtitleKdsId(
                                  kdsId.toString());
                            }
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          color: Colors.white.withOpacity(0.1),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: category['image'] != null &&
                                    category['image'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      category['image'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, o, s) => const Icon(
                                          Icons.broken_image_outlined,
                                          size: 30, color: Colors.white70),
                                    ),
                                  )
                                : Icon(Icons.category_outlined,
                                    size: 30, color: Colors.white70),
                            title:
                                Text(category['name'] ?? l10n.unknownCategory, style: textStyle),
                            subtitle: Text(
                                parentName.isNotEmpty
                                    ? "$parentName$kdsInfo"
                                    : kdsInfo.isNotEmpty
                                        ? kdsInfo.trim()
                                        : l10n.setupCategoriesKdsNotAssigned,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7))),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              tooltip: l10n.setupCategoriesDeleteTooltip,
                              onPressed: () => _deleteCategory(
                                  category['id'],
                                  category['name'] ??
                                      l10n.setupCategoriesDeleteFallbackName),
                            ),
                          ),
                        );
                      },
                    ),
          const SizedBox(height: 10),
          if (!_isLoadingScreenData)
            ValueListenableBuilder<SubscriptionLimits>(
              valueListenable: UserSession.limitsNotifier,
              builder: (context, limits, child) {
                // Hata veren `l10n` anahtarı yerine basit string birleştirme kullanıldı.
                return Text(
                  '${categories.length} / ${limits.maxCategories} Kategori Oluşturuldu',
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
// lib/widgets/setup_wizard/menu_items/dialogs/menu_item_variants_dialog.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../services/api_service.dart';
import '../../../../services/firebase_storage_service.dart';
import '../../../../models/menu_item_variant.dart';
import '../../../../services/user_session.dart';
import '../../../../screens/subscription_screen.dart';
import '../../../../services/localized_template_service.dart';
import '../../../../providers/language_provider.dart';
import '../components/variant_dialog_header.dart';
import '../components/variant_template_chips.dart';
import '../components/variant_form_section.dart';
import '../components/existing_variants_list.dart';
import '../components/variant_dialog_footer.dart';
import '../services/variant_template_service.dart';
import '../models/variant_dialog_state.dart';

class MenuItemVariantsDialog extends StatefulWidget {
  final String token;
  final int businessId;
  final Map<String, dynamic> menuItem;
  final VoidCallback onVariantsChanged;

  const MenuItemVariantsDialog({
    Key? key,
    required this.token,
    required this.businessId,
    required this.menuItem,
    required this.onVariantsChanged,
  }) : super(key: key);

  @override
  State<MenuItemVariantsDialog> createState() => _MenuItemVariantsDialogState();
}

class _MenuItemVariantsDialogState extends State<MenuItemVariantsDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _variantNameController = TextEditingController();
  final TextEditingController _variantPriceController = TextEditingController();
  
  late VariantDialogState _dialogState;
  late VariantTemplateService _templateService;

  @override
  void initState() {
    super.initState();
    _dialogState = VariantDialogState();
    _templateService = VariantTemplateService();
    _fetchVariants();
    _loadVariantTemplates();
  }

  @override
  void dispose() {
    _variantNameController.dispose();
    _variantPriceController.dispose();
    super.dispose();
  }

  Future<void> _fetchVariants() async {
    if (!mounted) return;
    setState(() => _dialogState.isLoading = true);

    try {
      final variantsData = await ApiService.fetchVariantsForMenuItem(
        widget.token,
        widget.menuItem['id']
      );
      
      if (mounted) {
        setState(() {
          _dialogState.variants = variantsData.map((v) => MenuItemVariant.fromJson(v)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _dialogState.message = l10n.menuItemVariantsDialogErrorLoadingVariants(e.toString().replaceFirst("Exception: ", ""));
        });
      }
    } finally {
      if (mounted) setState(() => _dialogState.isLoading = false);
    }
  }

  Future<void> _loadVariantTemplates() async {
    if (!mounted) return;
    setState(() {
      _dialogState.isLoadingTemplates = true;
      _dialogState.hasTemplateLoadError = false;
      _dialogState.templateErrorMessage = '';
    });

    try {
      final templates = await _templateService.loadVariantTemplates(
        widget.menuItem,
        widget.token,
      );

      if (mounted) {
        setState(() => _dialogState.variantTemplates = templates);
      }
    } catch (e) {
      debugPrint('❌ Varyant şablonları yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _dialogState.variantTemplates = _templateService.getDefaultVariantTemplates();
          _dialogState.hasTemplateLoadError = true;
          _dialogState.templateErrorMessage = 'Şablon yükleme hatası: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _dialogState.isLoadingTemplates = false);
    }
  }

  void _selectVariantTemplate(Map<String, dynamic> template) {
    try {
      setState(() {
        _variantNameController.text = template['name']?.toString() ?? '';
        
        // Base fiyat hesaplama - daha güvenli
        final menuItemPrice = widget.menuItem['price'];
        double basePrice = 25.0;
        
        if (menuItemPrice != null) {
          if (menuItemPrice is num) {
            basePrice = menuItemPrice.toDouble();
          } else if (menuItemPrice is String) {
            basePrice = double.tryParse(menuItemPrice) ?? 25.0;
          }
        }
        
        // price_multiplier kontrolü - daha güvenli
        double multiplier = 1.0;
        final multiplierValue = template['price_multiplier'];
        if (multiplierValue != null) {
          if (multiplierValue is num) {
            multiplier = multiplierValue.toDouble();
          } else if (multiplierValue is String) {
            multiplier = double.tryParse(multiplierValue) ?? 1.0;
          }
        }
        
        // Multiplier sınırlandır
        multiplier = multiplier.clamp(0.5, 3.0);
        
        final calculatedPrice = basePrice * multiplier;
        _variantPriceController.text = calculatedPrice.toStringAsFixed(2);
        
        // is_extra alanını daha güvenli parse et
        bool isExtra = false;
        final isExtraValue = template['is_extra'];
        if (isExtraValue != null) {
          if (isExtraValue is bool) {
            isExtra = isExtraValue;
          } else if (isExtraValue is String) {
            isExtra = isExtraValue.toLowerCase() == 'true' || isExtraValue == '1';
          } else if (isExtraValue is num) {
            isExtra = isExtraValue != 0;
          }
        }
        
        _dialogState.isExtraFlag = isExtra;
      });
      
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Template seçim hatası: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 70
    );
    
    if (image != null) {
      setState(() {
        if (kIsWeb) {
          _dialogState.webImageBytes = null;
          _dialogState.pickedImageXFile = null;
          image.readAsBytes().then((bytes) {
            setState(() => _dialogState.webImageBytes = bytes);
          });
        } else {
          _dialogState.pickedImageXFile = image;
          _dialogState.webImageBytes = null;
        }
      });
    }
  }

  void _showLimitReachedDialog() {
    final l10n = AppLocalizations.of(context)!;
    final currentLimits = UserSession.limitsNotifier.value;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dialogLimitReachedTitle),
        content: Text(l10n.menuItemVariantsDialogLimitReachedContent(currentLimits.maxVariants)),
        actions: [
          TextButton(
            child: Text(l10n.dialogButtonLater),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text(l10n.dialogButtonUpgradePlan),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const SubscriptionScreen())
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addVariant() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    // Limit kontrolü
    final currentLimits = UserSession.limitsNotifier.value;
    final totalVariantCount = _dialogState.variants.length;
    if (totalVariantCount >= currentLimits.maxVariants) {
      _showLimitReachedDialog();
      return;
    }

    setState(() {
      _dialogState.isSubmitting = true;
      _dialogState.message = '';
      _dialogState.successMessage = '';
    });

    String? imageUrl;
    if (_dialogState.pickedImageXFile != null || _dialogState.webImageBytes != null) {
      try {
        String fileName = _dialogState.pickedImageXFile != null
            ? p.basename(_dialogState.pickedImageXFile!.path)
            : 'variant_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        String firebaseFileName = "business_${widget.businessId}/menu_items/${widget.menuItem['id']}/variants/${DateTime.now().millisecondsSinceEpoch}_$fileName";

        imageUrl = await FirebaseStorageService.uploadImage(
          imageFile: _dialogState.pickedImageXFile != null ? File(_dialogState.pickedImageXFile!.path) : null,
          imageBytes: _dialogState.webImageBytes,
          fileName: firebaseFileName,
          folderPath: 'variant_images',
        );
        
        if (imageUrl == null) {
          throw Exception(l10n.menuItemVariantsDialogFirebaseUploadFailed);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _dialogState.message = l10n.menuItemVariantsDialogErrorUploadingPhoto(e.toString());
            _dialogState.isSubmitting = false;
          });
        }
        return;
      }
    }

    try {
      await ApiService.createMenuItemVariant(
        widget.token,
        widget.menuItem['id'],
        _variantNameController.text.trim(),
        double.tryParse(_variantPriceController.text.trim().replaceAll(',', '.')) ?? 0.0,
        _dialogState.isExtraFlag,
        imageUrl,
      );

      if (mounted) {
        setState(() {
          _dialogState.successMessage = l10n.menuItemVariantsDialogVariantAddedSuccess(_variantNameController.text.trim());
          _variantNameController.clear();
          _variantPriceController.clear();
          _dialogState.isExtraFlag = false;
          _dialogState.pickedImageXFile = null;
          _dialogState.webImageBytes = null;
        });
        
        await _fetchVariants();
        widget.onVariantsChanged();
        
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _dialogState.successMessage = '');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dialogState.message = e.toString().replaceFirst("Exception: ", "");
        });
        
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _dialogState.message = '');
          }
        });
      }
    } finally {
      if (mounted) setState(() => _dialogState.isSubmitting = false);
    }
  }

  Future<void> _deleteVariant(int variantId, String variantName) async {
    final l10n = AppLocalizations.of(context)!;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.menuItemVariantsDialogDeleteVariantTitle),
        content: Text(l10n.menuItemVariantsDialogDeleteVariantContent(variantName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.dialogButtonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.dialogButtonDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _dialogState.isLoading = true);
      
      try {
        await ApiService.deleteMenuItemVariant(widget.token, variantId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.menuItemVariantsDialogVariantDeletedSuccess(variantName)),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          await _fetchVariants();
          widget.onVariantsChanged();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _dialogState.message = l10n.menuItemVariantsDialogErrorDeletingVariant(e.toString().replaceFirst("Exception: ", ""));
          });
          
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() => _dialogState.message = '');
            }
          });
        }
      } finally {
        if (mounted) setState(() => _dialogState.isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final menuItemName = widget.menuItem['name'] ?? l10n.menuItemVariantsDialogUnnamedProduct;

    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            VariantDialogHeader(
              menuItemName: menuItemName,
              onClose: () => Navigator.of(context).pop(),
            ),
            
            const Divider(),
            const SizedBox(height: 8),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mevcut Varyantlar
                    ExistingVariantsList(
                      isLoading: _dialogState.isLoading,
                      variants: _dialogState.variants,
                      onDeleteVariant: _deleteVariant,
                    ),
                    
                    if (_dialogState.variants.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                    
                    // Yeni Varyant Ekleme Formu
                    Text(
                      l10n.menuItemVariantsDialogAddNewVariant,
                      style: TextStyle(
                        fontSize: 16,
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
                          VariantFormSection(
                            nameController: _variantNameController,
                            priceController: _variantPriceController,
                            isExtraFlag: _dialogState.isExtraFlag,
                            isSubmitting: _dialogState.isSubmitting,
                            onExtraFlagChanged: (value) => setState(() => _dialogState.isExtraFlag = value),
                            onPickImage: _pickImage,
                            pickedImageXFile: _dialogState.pickedImageXFile,
                            webImageBytes: _dialogState.webImageBytes,
                          ),
                          
                          // Hızlı varyant ekleme
                          VariantTemplateChips(
                            variantTemplates: _dialogState.variantTemplates,
                            isLoadingTemplates: _dialogState.isLoadingTemplates,
                            hasTemplateLoadError: _dialogState.hasTemplateLoadError,
                            templateErrorMessage: _dialogState.templateErrorMessage,
                            variants: _dialogState.variants,
                            onSelectTemplate: _selectVariantTemplate,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Ekle butonu
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _dialogState.isSubmitting ? null : _addVariant,
                              icon: _dialogState.isSubmitting 
                                  ? const SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(strokeWidth: 2)
                                    )
                                  : const Icon(Icons.add, size: 20),
                              label: Text(_dialogState.isSubmitting ? l10n.menuItemVariantsDialogAddingButton : l10n.menuItemVariantsDialogAddVariantButton),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _dialogState.isSubmitting ? Colors.grey : Colors.blue,
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
            VariantDialogFooter(
              successMessage: _dialogState.successMessage,
              errorMessage: _dialogState.message,
              onClose: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
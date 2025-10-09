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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    final availableHeight = screenHeight - keyboardHeight - 100.0;
    final double dialogHeight = availableHeight > 600.0 ? availableHeight : 600.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        height: dialogHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1565C0), // Koyu mavi
              const Color(0xFF1976D2), // Orta mavi
              const Color(0xFF1E88E5), // Açık mavi
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with gradient and glass effect
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.menuItemVariantsDialogTitle(menuItemName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content with glass effect
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mevcut Varyantlar
                        if (_dialogState.variants.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.check_circle_outline, 
                                        color: Colors.green.shade300, 
                                        size: 20
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.menuItemVariantsDialogCurrentVariants(_dialogState.variants.length),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ..._dialogState.variants.map((variant) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Varyant görseli
                                      if (variant.image.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.network(
                                            variant.image.startsWith('http')
                                                ? variant.image
                                                : '${ApiService.baseUrl}${variant.image}',
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, o, s) => Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.white.withOpacity(0.5),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.label_outline,
                                            color: Colors.white.withOpacity(0.5),
                                            size: 20,
                                          ),
                                        ),
                                      
                                      const SizedBox(width: 12),
                                      
                                      // Varyant bilgileri
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              variant.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  '₺${variant.price.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white.withOpacity(0.8),
                                                  ),
                                                ),
                                                if (variant.isExtra) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, 
                                                      vertical: 2
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.3),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      l10n.menuItemVariantsDialogExtraTag,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.orange.shade200,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Sil butonu
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: IconButton(
                                          onPressed: () => _deleteVariant(variant.id, variant.name),
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: Colors.red.shade300,
                                          ),
                                          tooltip: l10n.menuItemVariantsDialogDeleteVariantTooltip,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        // Yeni Varyant Ekleme Formu
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.add_circle_outline, 
                                        color: Colors.white, 
                                        size: 20
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.menuItemVariantsDialogAddNewVariant,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Varyant adı ve fiyat
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                                        ),
                                        child: TextFormField(
                                          controller: _variantNameController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            labelText: l10n.menuItemVariantsDialogVariantNameLabel,
                                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                            hintText: l10n.menuItemVariantsDialogVariantNameHint,
                                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          ),
                                          validator: (v) => (v == null || v.isEmpty) 
                                              ? l10n.menuItemVariantsDialogVariantNameRequired 
                                              : null,
                                          enabled: !_dialogState.isSubmitting,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                                        ),
                                        child: TextFormField(
                                          controller: _variantPriceController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            labelText: l10n.menuItemVariantsDialogPriceLabel,
                                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                            prefixText: '₺',
                                            prefixStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))
                                          ],
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return l10n.menuItemVariantsDialogPriceRequired;
                                            if (double.tryParse(v.replaceAll(',', '.')) == null) {
                                              return l10n.menuItemVariantsDialogInvalidPrice;
                                            }
                                            return null;
                                          },
                                          enabled: !_dialogState.isSubmitting,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Ekstra seçeneği
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.7),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          color: _dialogState.isExtraFlag 
                                              ? Colors.white 
                                              : Colors.transparent,
                                        ),
                                        child: _dialogState.isExtraFlag 
                                            ? Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.blue.shade800,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: _dialogState.isSubmitting ? null : () {
                                            setState(() {
                                              _dialogState.isExtraFlag = !_dialogState.isExtraFlag;
                                            });
                                          },
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                l10n.menuItemVariantsDialogExtraOptionTitle,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                l10n.menuItemVariantsDialogExtraOptionSubtitle,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Fotoğraf yükleme alanı
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.camera_alt, 
                                              color: Colors.orange.shade300, 
                                              size: 20
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              l10n.menuItemVariantsDialogVariantPhotoOptional,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (_dialogState.pickedImageXFile != null || _dialogState.webImageBytes != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Seçildi',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green.shade200,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Image preview
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.white38),
                                            ),
                                            child: _dialogState.webImageBytes != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.memory(
                                                      _dialogState.webImageBytes!,
                                                      height: 60,
                                                      width: 60,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : _dialogState.pickedImageXFile != null
                                                    ? ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Image.file(
                                                          File(_dialogState.pickedImageXFile!.path),
                                                          height: 60,
                                                          width: 60,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons.add_photo_alternate_outlined,
                                                        color: Colors.white70,
                                                        size: 24,
                                                      ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: BorderSide(color: Colors.white.withOpacity(0.5)),
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                              ),
                                              onPressed: _dialogState.isSubmitting ? null : _pickImage,
                                              icon: const Icon(Icons.photo_library_outlined),
                                              label: Text(l10n.menuItemVariantsDialogSelectImage),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Hızlı varyant ekleme chips
                                if (_dialogState.variantTemplates.isNotEmpty) ...[
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
                                            Icon(Icons.flash_on, color: Colors.orange.shade300, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              l10n.menuItemVariantsDialogQuickAddVariant,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (_dialogState.isLoadingTemplates) ...[
                                              const SizedBox(width: 8),
                                              const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _dialogState.isLoadingTemplates
                                            ? Center(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Text(
                                                    l10n.menuItemVariantsDialogLoadingTemplates,
                                                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                                  ),
                                                ),
                                              )
                                            : Wrap(
                                                spacing: 8.0,
                                                runSpacing: 8.0,
                                                children: _dialogState.variantTemplates.map<Widget>((template) {
                                                  final templateName = template['name']?.toString() ?? 'İsimsiz';
                                                  final isUsed = _dialogState.variants.any((variant) => 
                                                    variant.name.toLowerCase() == templateName.toLowerCase()
                                                  );
                                                  
                                                  return Container(
                                                    decoration: BoxDecoration(
                                                      color: isUsed 
                                                          ? Colors.white.withOpacity(0.1) 
                                                          : Colors.white.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isUsed 
                                                            ? Colors.white.withOpacity(0.2) 
                                                            : Colors.white.withOpacity(0.4),
                                                      ),
                                                    ),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: isUsed || _dialogState.isSubmitting ? null : () {
                                                          _selectVariantTemplate(template);
                                                        },
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                          child: Text(
                                                            templateName,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                              color: isUsed 
                                                                  ? Colors.white.withOpacity(0.5) 
                                                                  : Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                
                                // Ekle butonu
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _dialogState.isSubmitting ? null : _addVariant,
                                    icon: _dialogState.isSubmitting 
                                        ? const SizedBox(
                                            width: 20, 
                                            height: 20, 
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.blue,
                                            )
                                          )
                                        : const Icon(Icons.add, size: 20),
                                    label: Text(
                                      _dialogState.isSubmitting 
                                          ? l10n.menuItemVariantsDialogAddingButton 
                                          : l10n.menuItemVariantsDialogAddVariantButton,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _dialogState.isSubmitting ? Colors.white.withOpacity(0.3) : Colors.white,
                                      foregroundColor: _dialogState.isSubmitting ? Colors.white.withOpacity(0.5) : Colors.blue.shade700,
                                      disabledBackgroundColor: Colors.white.withOpacity(0.3),
                                      disabledForegroundColor: Colors.white.withOpacity(0.5),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                      shadowColor: Colors.black.withOpacity(0.3),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Footer/Actions with gradient
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16.0),
                  bottomRight: Radius.circular(16.0),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Success/Error messages
                    if (_dialogState.successMessage.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Text(
                          _dialogState.successMessage,
                          style: TextStyle(
                            color: Colors.green.shade200,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    if (_dialogState.message.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          _dialogState.message,
                          style: TextStyle(
                            color: Colors.red.shade200,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Close button
                    Expanded(
                      child: Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.9),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            ),
                          ),
                          child: Text(
                            l10n.menuItemVariantsDialogCloseButton,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
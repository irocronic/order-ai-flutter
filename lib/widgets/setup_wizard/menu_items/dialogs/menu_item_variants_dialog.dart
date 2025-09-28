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
  bool _isExtraFlag = false;

  List<MenuItemVariant> _variants = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _message = '';
  String _successMessage = '';

  XFile? _pickedImageXFile;
  Uint8List? _webImageBytes;

  // Varyant şablonları
  List<dynamic> _variantTemplates = [];
  bool _isLoadingTemplates = false;
  
  // ✅ YENİ: Hata durumu tracking
  bool _hasTemplateLoadError = false;
  String _templateErrorMessage = '';

  @override
  void initState() {
    super.initState();
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
    setState(() => _isLoading = true);

    try {
      final variantsData = await ApiService.fetchVariantsForMenuItem(
        widget.token,
        widget.menuItem['id']
      );
      
      if (mounted) {
        setState(() {
          _variants = variantsData.map((v) => MenuItemVariant.fromJson(v)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _message = l10n.menuItemVariantsDialogErrorLoadingVariants(e.toString().replaceFirst("Exception: ", ""));
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ GÜNCELLEME: Daha güvenli template yükleme
  Future<void> _loadVariantTemplates() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTemplates = true;
      _hasTemplateLoadError = false;
      _templateErrorMessage = '';
    });

    try {
      final category = widget.menuItem['category'];
      String? categoryName;
      
      if (category != null) {
        if (category is Map<String, dynamic>) {
          categoryName = category['name'] as String?;
        }
      }

      List<dynamic> templates = [];
      
      // ✅ DÜZELTME: Öncelikle JSON dosyasından varyant şablonlarını yükle
      try {
        final languageCode = LanguageProvider.currentLanguageCode;
        final jsonTemplates = await LocalizedTemplateService.loadVariants(languageCode);
        
        if (jsonTemplates.isNotEmpty) {
          // Kategori bazlı filtreleme yapabiliriz (opsiyonel)
          if (categoryName != null) {
            // Basit kategori eşleştirmesi - gerekirse daha gelişmiş bir algoritma yapılabilir
            templates = jsonTemplates.take(8).toList();
          } else {
            templates = jsonTemplates.take(8).toList();
          }
          
          debugPrint('✅ JSON\'dan ${templates.length} varyant şablonu yüklendi');
        }
      } catch (jsonError) {
        debugPrint('⚠️ JSON varyant şablonları yüklenemedi: $jsonError');
        
        // ✅ YENİ: JSON yüklenemezse daha güvenli fallback
        templates = _getDefaultVariantTemplates();
        debugPrint('✅ Varsayılan şablonlar kullanılıyor: ${templates.length} adet');
      }
      
      // ✅ YENİ: Eğer JSON'dan hiç template yüklenmediyse API'den dene (isteğe bağlı)
      if (templates.isEmpty) {
        try {
          if (categoryName != null) {
            templates = await ApiService.fetchVariantTemplates(
              widget.token,
              categoryTemplateName: categoryName,
            );
            debugPrint('✅ API\'den kategori bazlı ${templates.length} varyant şablonu yüklendi');
          }

          if (templates.isEmpty) {
            final defaultTemplates = await ApiService.fetchVariantTemplates(widget.token);
            templates = defaultTemplates.take(6).toList();
            debugPrint('✅ API\'den varsayılan ${templates.length} varyant şablonu yüklendi');
          }
        } catch (apiError) {
          debugPrint('❌ API varyant şablonları da yüklenemedi: $apiError');
          // ✅ YENİ: API de başarısızsa tamamen varsayılan şablonları kullan
          templates = _getDefaultVariantTemplates();
          setState(() {
            _hasTemplateLoadError = true;
            _templateErrorMessage = 'Şablonlar yüklenemedi, varsayılan seçenekler kullanılıyor.';
          });
        }
      }

      if (mounted) {
        setState(() => _variantTemplates = templates);
      }
    } catch (e) {
      debugPrint('❌ Varyant şablonları yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _variantTemplates = _getDefaultVariantTemplates();
          _hasTemplateLoadError = true;
          _templateErrorMessage = 'Şablon yükleme hatası: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  // ✅ YENİ: Varsayılan varyant şablonları
  List<dynamic> _getDefaultVariantTemplates() {
    return [
      {
        'id': -1,
        'name': 'Büyük',
        'price_multiplier': 1.3,
        'is_extra': false,
        'icon_name': 'restaurant'
      },
      {
        'id': -2,
        'name': 'Orta',
        'price_multiplier': 1.0,
        'is_extra': false,
        'icon_name': 'restaurant_outlined'
      },
      {
        'id': -3,
        'name': 'Küçük',
        'price_multiplier': 0.8,
        'is_extra': false,
        'icon_name': 'restaurant_outlined'
      },
      {
        'id': -4,
        'name': 'Ekstra Malzemeli',
        'price_multiplier': 1.2,
        'is_extra': true,
        'icon_name': 'add_circle'
      },
      {
        'id': -5,
        'name': 'Az Baharatlı',
        'price_multiplier': 1.0,
        'is_extra': false,
        'icon_name': 'whatshot'
      },
      {
        'id': -6,
        'name': 'Çok Baharatlı',
        'price_multiplier': 1.1,
        'is_extra': false,
        'icon_name': 'whatshot'
      },
    ];
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'restaurant_outlined': return Icons.restaurant_outlined;
      case 'restaurant': return Icons.restaurant;
      case 'dinner_dining': return Icons.dinner_dining;
      case 'local_cafe': return Icons.local_cafe;
      case 'cake': return Icons.cake;
      case 'fastfood': return Icons.fastfood;
      case 'lunch_dining': return Icons.lunch_dining;
      case 'local_bar': return Icons.local_bar;
      case 'wine_bar': return Icons.wine_bar;
      case 'whatshot': return Icons.whatshot;
      case 'ac_unit': return Icons.ac_unit;
      case 'favorite': return Icons.favorite;
      case 'mood': return Icons.mood;
      case 'add_circle': return Icons.add_circle;
      case 'local_drink': return Icons.local_drink;
      case 'sports_bar': return Icons.sports_bar;
      default: return Icons.label_outline;
    }
  }

  // ✅ GÜNCELLEME: Daha güvenli template seçimi
  void _selectVariantTemplate(Map<String, dynamic> template) {
    try {
      setState(() {
        _variantNameController.text = template['name']?.toString() ?? '';
        
        // Base fiyat hesaplama - daha güvenli
        final menuItemPrice = widget.menuItem['price'];
        double basePrice = 25.0; // Varsayılan fiyat artırıldı
        
        if (menuItemPrice != null) {
          if (menuItemPrice is num) {
            basePrice = menuItemPrice.toDouble();
          } else if (menuItemPrice is String) {
            basePrice = double.tryParse(menuItemPrice) ?? 25.0;
          }
        }
        
        // ✅ DÜZELTME: price_multiplier kontrolü - daha güvenli
        double multiplier = 1.0;
        final multiplierValue = template['price_multiplier'];
        if (multiplierValue != null) {
          if (multiplierValue is num) {
            multiplier = multiplierValue.toDouble();
          } else if (multiplierValue is String) {
            multiplier = double.tryParse(multiplierValue) ?? 1.0;
          }
        }
        
        // ✅ YENİ: Multiplier sınırlandır
        multiplier = multiplier.clamp(0.5, 3.0); // 0.5x ile 3x arasında sınırla
        
        final calculatedPrice = basePrice * multiplier;
        _variantPriceController.text = calculatedPrice.toStringAsFixed(2);
        
        // ✅ GÜNCELLEME: is_extra alanını daha güvenli parse et
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
        
        _isExtraFlag = isExtra;
      });
      
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('❌ Template seçim hatası: $e');
      // Hata durumunda hiçbir şey yapma, mevcut değerleri koru
    }
  }

  Widget _buildQuickVariantChips() {
    if (_variantTemplates.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange, size: 16),
            const SizedBox(width: 4),
            Text(
              l10n.menuItemVariantsDialogQuickAddVariant,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_isLoadingTemplates) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ],
            // ✅ YENİ: Hata durumu gösterici
            if (_hasTemplateLoadError) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: _templateErrorMessage,
                child: Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: _isLoadingTemplates
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      l10n.menuItemVariantsDialogLoadingTemplates,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _variantTemplates.map<Widget>((template) {
                    final templateName = template['name']?.toString() ?? 'İsimsiz';
                    final isUsed = _variants.any((variant) => 
                      variant.name.toLowerCase() == templateName.toLowerCase()
                    );
                    
                    return ActionChip(
                      avatar: Icon(
                        _getIconFromName(template['icon_name']?.toString() ?? 'label_outline'),
                        size: 16,
                        color: isUsed ? Colors.grey : Colors.orange.shade700,
                      ),
                      label: Text(
                        templateName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isUsed ? Colors.grey : Colors.orange.shade700,
                        ),
                      ),
                      backgroundColor: isUsed ? Colors.grey.shade200 : Colors.white,
                      onPressed: isUsed ? null : () => _selectVariantTemplate(template),
                      elevation: isUsed ? 0 : 2,
                      pressElevation: 1,
                      side: BorderSide(
                        color: isUsed 
                            ? Colors.grey.shade300 
                            : Colors.orange.withOpacity(0.3),
                        width: 1,
                      ),
                    );
                  }).toList(),
                ),
        ),
        // ✅ YENİ: Hata mesajı göster
        if (_hasTemplateLoadError)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _templateErrorMessage,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
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
          _webImageBytes = null;
          _pickedImageXFile = null;
          image.readAsBytes().then((bytes) {
            setState(() => _webImageBytes = bytes);
          });
        } else {
          _pickedImageXFile = image;
          _webImageBytes = null;
        }
      });
    }
  }

  Widget _buildImagePreview() {
    Widget placeholder = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(
        Icons.add_photo_alternate_outlined, 
        color: Colors.grey.shade500, 
        size: 24
      ),
    );

    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _webImageBytes!, 
          height: 60, 
          width: 60, 
          fit: BoxFit.cover
        ),
      );
    } else if (!kIsWeb && _pickedImageXFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(_pickedImageXFile!.path), 
          height: 60, 
          width: 60, 
          fit: BoxFit.cover
        ),
      );
    }
    
    return placeholder;
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
              Navigator.of(context).pop(); // Dialog'u kapat
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
    final totalVariantCount = _variants.length;
    if (totalVariantCount >= currentLimits.maxVariants) {
      _showLimitReachedDialog();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = '';
      _successMessage = '';
    });

    String? imageUrl;
    if (_pickedImageXFile != null || _webImageBytes != null) {
      try {
        String fileName = _pickedImageXFile != null
            ? p.basename(_pickedImageXFile!.path)
            : 'variant_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        String firebaseFileName = "business_${widget.businessId}/menu_items/${widget.menuItem['id']}/variants/${DateTime.now().millisecondsSinceEpoch}_$fileName";

        imageUrl = await FirebaseStorageService.uploadImage(
          imageFile: _pickedImageXFile != null ? File(_pickedImageXFile!.path) : null,
          imageBytes: _webImageBytes,
          fileName: firebaseFileName,
          folderPath: 'variant_images',
        );
        
        if (imageUrl == null) {
          throw Exception(l10n.menuItemVariantsDialogFirebaseUploadFailed);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _message = l10n.menuItemVariantsDialogErrorUploadingPhoto(e.toString());
            _isSubmitting = false;
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
        _isExtraFlag,
        imageUrl,
      );

      if (mounted) {
        setState(() {
          _successMessage = l10n.menuItemVariantsDialogVariantAddedSuccess(_variantNameController.text.trim());
          _variantNameController.clear();
          _variantPriceController.clear();
          _isExtraFlag = false;
          _pickedImageXFile = null;
          _webImageBytes = null;
        });
        
        // Varyantları yenile
        await _fetchVariants();
        widget.onVariantsChanged();
        
        // Mesajı temizle
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _successMessage = '');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e.toString().replaceFirst("Exception: ", "");
        });
        
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _message = '');
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      setState(() => _isLoading = true);
      
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
            _message = l10n.menuItemVariantsDialogErrorDeletingVariant(e.toString().replaceFirst("Exception: ", ""));
          });
          
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() => _message = '');
            }
          });
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
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
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.menuItemVariantsDialogTitle(menuItemName),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                    // Mevcut Varyantlar
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_variants.isNotEmpty) ...[
                      Text(
                        l10n.menuItemVariantsDialogCurrentVariants(_variants.length),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_variants.map((variant) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
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
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey.shade500,
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
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.label_outline,
                                  color: Colors.grey.shade500,
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6, 
                                            vertical: 2
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            l10n.menuItemVariantsDialogExtraTag,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange.shade700,
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
                            IconButton(
                              onPressed: () => _deleteVariant(variant.id, variant.name),
                              icon: Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red.shade600,
                              ),
                              tooltip: l10n.menuItemVariantsDialogDeleteVariantTooltip,
                            ),
                          ],
                        ),
                      ))),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.tune,
                              size: 48,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.menuItemVariantsDialogNoVariantsAdded,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.menuItemVariantsDialogNoVariantsDescription,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _variantNameController,
                                  decoration: InputDecoration(
                                    labelText: l10n.menuItemVariantsDialogVariantNameLabel,
                                    hintText: l10n.menuItemVariantsDialogVariantNameHint,
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, 
                                      vertical: 16
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) 
                                      ? l10n.menuItemVariantsDialogVariantNameRequired 
                                      : null,
                                  enabled: !_isSubmitting,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _variantPriceController,
                                  decoration: InputDecoration(
                                    labelText: l10n.menuItemVariantsDialogPriceLabel,
                                    prefixText: '₺',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, 
                                      vertical: 16
                                    ),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*[\.,]?\d{0,2}')
                                    )
                                  ],
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return l10n.menuItemVariantsDialogPriceRequired;
                                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                                      return l10n.menuItemVariantsDialogInvalidPrice;
                                    }
                                    return null;
                                  },
                                  enabled: !_isSubmitting,
                                ),
                              ),
                            ],
                          ),
                          
                          // Hızlı varyant ekleme
                          _buildQuickVariantChips(),
                          
                          const SizedBox(height: 16),
                          
                          // Seçenekler
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  title: Text(l10n.menuItemVariantsDialogExtraOptionTitle),
                                  subtitle: Text(l10n.menuItemVariantsDialogExtraOptionSubtitle),
                                  value: _isExtraFlag,
                                  onChanged: _isSubmitting 
                                      ? null 
                                      : (val) => setState(() => _isExtraFlag = val ?? false),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Fotoğraf yükleme alanı
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.camera_alt, 
                                      color: Colors.blue.shade700, 
                                      size: 20
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.menuItemVariantsDialogVariantPhotoOptional,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
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
                                          foregroundColor: Colors.blue.shade700,
                                          side: BorderSide(
                                            color: Colors.blue.withOpacity(0.3)
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12
                                          ),
                                        ),
                                        onPressed: _isSubmitting ? null : _pickImage,
                                        icon: const Icon(Icons.photo_library_outlined),
                                        label: Text(l10n.menuItemVariantsDialogSelectImage),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Ekle butonu
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : _addVariant,
                              icon: _isSubmitting 
                                  ? const SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(strokeWidth: 2)
                                    )
                                  : const Icon(Icons.add, size: 20),
                              label: Text(_isSubmitting ? l10n.menuItemVariantsDialogAddingButton : l10n.menuItemVariantsDialogAddVariantButton),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSubmitting ? Colors.grey : Colors.blue,
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
            
            // Success/Error messages
            if (_successMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  _successMessage,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            if (_message.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Footer
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.menuItemVariantsDialogCloseButton),
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
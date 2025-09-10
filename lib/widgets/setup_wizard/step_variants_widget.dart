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
import '../../services/setup_wizard_audio_service.dart'; // 🎵 YENİ EKLENEN
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

  // === YENİ: API'den gelen varyant şablonları ===
  List<dynamic> _variantTemplates = [];
  bool _isLoadingTemplates = false;

  // 🎵 YENİ EKLENEN: Audio servis referansı
  final SetupWizardAudioService _audioService = SetupWizardAudioService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      l10n = AppLocalizations.of(context)!;
      _fetchMenuItems();
      _didFetchData = true;
      
      // 🎵 YENİ EKLENEN: Sesli rehberliği başlat
      _startVoiceGuidance();
    }
  }

  // 🎵 YENİ EKLENEN: Sesli rehberlik başlatma
  void _startVoiceGuidance() {
    // Biraz bekle ki kullanıcı ekranı görsün
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _audioService.playVariantsStepAudio(context: context);
      }
    });
  }

  @override
  void dispose() {
    // Sesli rehberliği durdur
    _audioService.stopAudio();
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

  // === YENİ: API'den varyant şablonlarını getir ===
  Future<void> _loadVariantTemplatesForCategory() async {
    if (_selectedMenuItem?.category == null || !mounted) return;
    
    setState(() => _isLoadingTemplates = true);
    
    try {
      final categoryName = _selectedMenuItem!.category!['name'] as String;
      final templates = await ApiService.fetchVariantTemplates(
        widget.token,
        categoryTemplateName: categoryName,
      );
      
      if (mounted) {
        setState(() {
          _variantTemplates = templates;
        });
      }
    } catch (e) {
      if (mounted) {
        // Eğer kategori için özel şablon yoksa, varsayılan şablonları dene
        try {
          final defaultTemplates = await ApiService.fetchVariantTemplates(widget.token);
          if (mounted) {
            setState(() {
              _variantTemplates = defaultTemplates.take(4).toList(); // İlk 4 tanesi
            });
          }
        } catch (e2) {
          debugPrint('Varyant şablonları yüklenemedi: $e2');
          setState(() {
            _variantTemplates = [];
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  // === YENİ: Icon name'den IconData'ya dönüştürme ===
  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'restaurant_outlined': return Icons.restaurant_outlined;
      case 'restaurant': return Icons.restaurant;
      case 'dinner_dining': return Icons.dinner_dining;
      case 'dining': return Icons.dining;
      case 'mood': return Icons.mood;
      case 'whatshot_outlined': return Icons.whatshot_outlined;
      case 'whatshot': return Icons.whatshot;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'soup_kitchen_outlined': return Icons.soup_kitchen_outlined;
      case 'soup_kitchen': return Icons.soup_kitchen;
      case 'cake_outlined': return Icons.cake_outlined;
      case 'cake': return Icons.cake;
      case 'no_food': return Icons.no_food;
      case 'add_circle': return Icons.add_circle;
      case 'local_cafe_outlined': return Icons.local_cafe_outlined;
      case 'local_cafe': return Icons.local_cafe;
      case 'coffee': return Icons.coffee;
      case 'no_drinks': return Icons.no_drinks;
      case 'opacity': return Icons.opacity;
      case 'water_drop': return Icons.water_drop;
      case 'heart_broken': return Icons.heart_broken;
      case 'favorite_border': return Icons.favorite_border;
      case 'favorite': return Icons.favorite;
      case 'local_drink_outlined': return Icons.local_drink_outlined;
      case 'local_drink': return Icons.local_drink;
      case 'sports_bar': return Icons.sports_bar;
      case 'liquor': return Icons.liquor;
      case 'ac_unit': return Icons.ac_unit;
      case 'block': return Icons.block;
      case 'local_bar_outlined': return Icons.local_bar_outlined;
      case 'local_bar': return Icons.local_bar;
      case 'wine_bar': return Icons.wine_bar;
      case 'fastfood_outlined': return Icons.fastfood_outlined;
      case 'fastfood': return Icons.fastfood;
      case 'lunch_dining': return Icons.lunch_dining;
      case 'add': return Icons.add;
      default: return Icons.label_outline;
    }
  }

  // === GÜNCELLEME: API'den gelen şablon ile doldurma ===
  void _selectVariantTemplate(Map<String, dynamic> template) {
    setState(() {
      _variantNameController.text = template['name'];
      
      // Base fiyat kontrolü null safety ile
      final basePrice = _selectedMenuItem?.price;
      if (basePrice != null && basePrice > 0) {
        final multiplier = (template['price_multiplier'] as num).toDouble();
        final calculatedPrice = basePrice * multiplier;
        _variantPriceController.text = calculatedPrice.toStringAsFixed(2);
      } else {
        // Eğer base fiyat yoksa, varsayılan bir fiyat öner
        final multiplier = (template['price_multiplier'] as num).toDouble();
        final defaultPrice = 10.0 * multiplier; // 10 TL base fiyat varsayımı
        _variantPriceController.text = defaultPrice.toStringAsFixed(2);
      }
    });
    
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  // === YENİ: Quick Add Chips Widget ===
  Widget _buildQuickVariantChips() {
    if (_variantTemplates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.flash_on, color: Colors.yellow, size: 16),
            const SizedBox(width: 4),
            Text(
              'Hızlı Varyant Ekle:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_isLoadingTemplates) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: _isLoadingTemplates
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Şablonlar yükleniyor...',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _variantTemplates.map<Widget>((template) {
                    final isUsed = _addedVariants.any((variant) => 
                      variant.name.toLowerCase() == template['name'].toString().toLowerCase()
                    );
                    
                    return ActionChip(
                      avatar: Icon(
                        _getIconFromName(template['icon_name']),
                        size: 16,
                        color: isUsed ? Colors.grey : Colors.blue.shade700,
                      ),
                      label: Text(
                        template['name'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isUsed ? Colors.grey : Colors.blue.shade700,
                        ),
                      ),
                      backgroundColor: isUsed ? Colors.grey.shade200 : Colors.white,
                      onPressed: isUsed ? null : () => _selectVariantTemplate(template),
                      elevation: isUsed ? 0 : 2,
                      pressElevation: 1,
                      tooltip: isUsed ? 'Bu varyant zaten eklenmiş' : 'Tek tıkla ekle: ${template['name']}',
                    );
                  }).toList(),
                ),
        ),
      ],
    );
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

  // 🎵 YENİ EKLENEN: Ses kontrol butonu
  Widget _buildAudioControlButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: ValueNotifier(_audioService.isMuted),
      builder: (context, isMuted, child) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ses durumu göstergesi
              if (_audioService.isPlaying)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Sesli Rehber Aktif',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Sessizlik/Açma butonu
              IconButton(
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white.withOpacity(0.9),
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _audioService.toggleMute();
                  });
                },
                tooltip: isMuted ? 'Sesi Aç' : 'Sesi Kapat',
                style: IconButton.styleFrom(
                  backgroundColor: isMuted 
                    ? Colors.red.withOpacity(0.2) 
                    : Colors.blue.withOpacity(0.2),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              
              // Tekrar çal butonu
              IconButton(
                icon: Icon(
                  Icons.replay,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                onPressed: _audioService.isMuted ? null : () {
                  _audioService.playVariantsStepAudio(context: context);
                },
                tooltip: 'Rehberi Tekrar Çal',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        );
      },
    );
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
          // 🎵 YENİ EKLENEN: Sesli rehber kontrolleri
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildAudioControlButton(),
            ],
          ),
          const SizedBox(height: 16),

          // Başlık bilgisi
          Text(
            'Ürün varyantlarınızı ekleyin. Fiyatları ve varyantları bir sonraki adımda ekleyebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
          ),
          const SizedBox(height: 24),
          
          // Ana ürün seçimi
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
                  _variantTemplates = []; // Şablonları temizle
                  if (_selectedMenuItem != null) {
                    _fetchVariantsForSelectedMenuItem();
                    _loadVariantTemplatesForCategory(); // YENİ: Şablonları yükle
                  }
                });
              },
              validator: (value) => value == null ? l10n.setupVariantsValidatorSelectMainProduct : null,
            ),
          const SizedBox(height: 16),
          
          // Varyant ekleme formu
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
                    
                    // Varyant Adı field
                    TextFormField(
                      controller: _variantNameController,
                      style: textStyle,
                      decoration: inputDecoration.copyWith(
                        labelText: l10n.setupVariantsLabelVariantName,
                        prefixIcon: const Icon(Icons.local_offer_outlined),
                        hintText: 'Örn: Büyük, Acılı, 50cl...',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? l10n.variantNameValidator : null,
                    ),
                    
                    // === YENİ: Quick Add Chips (API'den gelen) ===
                    _buildQuickVariantChips(),
                    
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _variantPriceController,
                      style: textStyle,
                      decoration: inputDecoration.copyWith(
                        labelText: l10n.variantPriceLabel,
                        prefixIcon: const Icon(Icons.price_change_outlined),
                        suffixText: '₺',
                        hintText: 'Otomatik hesaplanacak',
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
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(l10n.variantIsExtraLabel, style: textStyle),
                      subtitle: Text(
                        'Bu seçenek ek ücretli bir özellik mi?',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
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
          
          // Eklenen varyantlar listesi
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
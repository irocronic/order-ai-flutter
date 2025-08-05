// lib/screens/add_edit_campaign_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:collection/collection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/campaign_service.dart';
import '../services/order_service.dart';
import '../models/campaign_menu.dart';
import '../models/campaign_menu_item.dart';
import '../models/menu_item.dart' as AppMenuItem;
import '../models/menu_item_variant.dart';
import '../widgets/add_order_item_dialog.dart';
// YENİ: Kategori düzenleme ekranına yönlendirme için import eklendi.
import 'edit_category_screen.dart';


class AddEditCampaignScreen extends StatefulWidget {
  final String token;
  final int businessId;
  final CampaignMenu? campaignMenu;

  const AddEditCampaignScreen({
    Key? key,
    required this.token,
    required this.businessId,
    this.campaignMenu,
  }) : super(key: key);

  @override
  _AddEditCampaignScreenState createState() => _AddEditCampaignScreenState();
}

class _AddEditCampaignScreenState extends State<AddEditCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _campaignPriceController;
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;

  XFile? _pickedImageXFile;
  Uint8List? _webImageBytes;
  String? _currentImageUrl;

  List<CampaignMenuItem> _selectedCampaignItems = [];
  List<AppMenuItem.MenuItem> _availableMenuItems = [];
  List<dynamic> _availableCategories = [];

  bool _isLoading = false;
  bool _isLoadingMenuItems = true;
  String _errorMessageKey = ''; // Hata anahtarını ve detayını tutar

  double _calculatedNormalTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.campaignMenu?.name ?? '');
    _descriptionController = TextEditingController(text: widget.campaignMenu?.description ?? '');
    _campaignPriceController = TextEditingController(text: widget.campaignMenu?.campaignPrice.toStringAsFixed(2) ?? '');
    _isActive = widget.campaignMenu?.isActive ?? true;
    _currentImageUrl = widget.campaignMenu?.image;
    if (widget.campaignMenu?.startDate != null) {
      _startDate = DateTime.tryParse(widget.campaignMenu!.startDate!);
    }
    if (widget.campaignMenu?.endDate != null) {
      _endDate = DateTime.tryParse(widget.campaignMenu!.endDate!);
    }
    if (widget.campaignMenu != null) {
      _selectedCampaignItems = List.from(widget.campaignMenu!.campaignItems);
    }
  }
  
  @override
  void didChangeDependencies() {
      super.didChangeDependencies();
      if (_isLoadingMenuItems) { // Sadece ilk seferde çalıştır
          _fetchInitialData();
      }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _campaignPriceController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if(!mounted) return;
    try {
      final results = await Future.wait([
        OrderService.fetchMenuItems(widget.token),
        OrderService.fetchCategories(widget.token),
      ]);

      if (mounted) {
        final menuData = results[0] as List<dynamic>;
        final categoryData = results[1] as List<dynamic>;
        
        setState(() {
          _availableMenuItems = menuData.map((e) => AppMenuItem.MenuItem.fromJson(e)).toList();
          _availableCategories = categoryData;
          _errorMessageKey = '';
          _recalculateNormalTotal();
          _isLoadingMenuItems = false; // Yükleme tamamlandı
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _errorMessageKey = "errorLoadingDataWithDetails|${e.toString()}";
        _isLoadingMenuItems = false;
      });
    }
  }

  void _openAddItemDialog() async {
    if (!mounted) return;
    await showDialog(
        context: context,
        builder: (_) => AddOrderItemDialog(
              token: widget.token,
              allMenuItems: _availableMenuItems,
              categories: _availableCategories,
              tableUsers: const [],
              onItemsAdded: (menuItem, variant, extras, tableUser) {
                if (mounted) {
                  setState(() {
                    const int quantity = 1;
                    final existingIndex = _selectedCampaignItems.indexWhere((ci) =>
                        ci.menuItemId == menuItem.id && ci.variantId == variant?.id);

                    if (existingIndex != -1) {
                      _selectedCampaignItems[existingIndex] = CampaignMenuItem(
                        id: _selectedCampaignItems[existingIndex].id,
                        menuItemId: menuItem.id,
                        menuItemName: menuItem.name,
                        variantId: variant?.id,
                        variantName: variant?.name,
                        quantity: (_selectedCampaignItems[existingIndex].quantity + quantity).toInt(),
                        originalPrice: variant?.price ?? 0.0,
                      );
                    } else {
                      _selectedCampaignItems.add(CampaignMenuItem(
                        menuItemId: menuItem.id,
                        menuItemName: menuItem.name,
                        variantId: variant?.id,
                        variantName: variant?.name,
                        quantity: quantity,
                        originalPrice: variant?.price ?? 0.0,
                      ));
                    }
                    _recalculateNormalTotal();
                  });
                }
              },
            ));
  }

  void _recalculateNormalTotal() {
    double total = 0;
    for (var campaignItem in _selectedCampaignItems) {
      final menuItem = _availableMenuItems.firstWhereOrNull((mi) => mi.id == campaignItem.menuItemId);
      if (menuItem == null) continue;

      if (campaignItem.variantId != null) {
        final variant = menuItem.variants?.firstWhereOrNull((v) => v.id == campaignItem.variantId);
        if (variant != null) {
          total += variant.price * campaignItem.quantity;
        }
      }
    }
    if(mounted) setState(() => _calculatedNormalTotal = total);
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

  Widget _buildImagePreview(AppLocalizations l10n) {
    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(_webImageBytes!, height: 100, width: 100, fit: BoxFit.cover);
    } else if (!kIsWeb && _pickedImageXFile != null) {
      return Image.file(File(_pickedImageXFile!.path), height: 100, width: 100, fit: BoxFit.cover);
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return Image.network(_currentImageUrl!, height: 100, width: 100, fit: BoxFit.cover,
        errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50),
      );
    }
    return Text(l10n.campaignImageNotSelected);
  }

  // --- YENİ METOT ---
  /// Kampanya oluşturulduktan sonra "Kampanyalar" kategorisinin KDS atamasını kontrol eder.
  Future<void> _handlePostCampaignCreation(BuildContext buildContext) async {
    final l10n = AppLocalizations.of(buildContext)!;
    try {
      final allBusinessCategories = await ApiService.fetchCategoriesForBusiness(widget.token);
      final campaignCategoryName = l10n.defaultCampaignCategoryName;
      final campaignCategory = allBusinessCategories.firstWhereOrNull(
          (cat) => cat['name'] == campaignCategoryName);
      
      if (campaignCategory != null) {
        final assignedKds = campaignCategory['assigned_kds'];
        if (assignedKds == null) {
          final bool? assignNow = await showDialog<bool>(
            context: buildContext,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.campaignKdsAssignmentTitle),
              content: Text(l10n.campaignKdsAssignmentPrompt(campaignCategoryName)),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.dialogButtonLater)),
                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.dialogButtonAssignNow)),
              ],
            ),
          );
          
          if (assignNow == true && mounted) {
            Navigator.pop(context, true); // Önce kampanya oluşturma ekranını kapat
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditCategoryScreen(
                  token: widget.token,
                  category: campaignCategory,
                  businessId: widget.businessId,
                  onMenuUpdated: () {}, // Bu ekrandan sonra özel bir aksiyon gerekmiyor
                ),
              ),
            );
            return; // Yönlendirme yapıldığı için metottan çık
          }
        }
      }
    } catch (e) {
      debugPrint("KDS atama kontrolü sırasında hata: $e");
    }

    // Eğer KDS ataması gerekmiyorsa veya kullanıcı "Daha Sonra" dediyse, normal şekilde çık
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _submitCampaign() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCampaignItems.isEmpty) {
      if(mounted) setState(() => _errorMessageKey = "campaignErrorAddItem");
      return;
    }
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessageKey = '';
    });

    String? imageUrl = _currentImageUrl;
    if (_pickedImageXFile != null || _webImageBytes != null) {
      try {
        String fileName = _pickedImageXFile != null ? p.basename(_pickedImageXFile!.path) : 'campaign_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String firebaseFileName = "business_${widget.businessId}/campaigns/${DateTime.now().millisecondsSinceEpoch}_$fileName";
        imageUrl = await FirebaseStorageService.uploadImage(
          imageFile: _pickedImageXFile != null ? File(_pickedImageXFile!.path) : null,
          imageBytes: _webImageBytes,
          fileName: firebaseFileName,
          folderPath: 'campaign_images');
        if (imageUrl == null) throw Exception(l10n.errorFirebaseUploadFailed);
      } catch (e) {
        if (mounted) setState(() {
          _errorMessageKey = "errorUploadingPhotoWithDetails|${e.toString()}";
          _isLoading = false;
        });
        return;
      }
    }

    final campaignData = CampaignMenu(
      id: widget.campaignMenu?.id ?? 0,
      businessId: widget.businessId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      campaignPrice: double.tryParse(_campaignPriceController.text.trim()) ?? 0.0,
      isActive: _isActive,
      image: imageUrl,
      startDate: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
      endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      campaignItems: _selectedCampaignItems,
    );

    try {
      if (widget.campaignMenu == null) {
        await CampaignService.createCampaign(widget.token, campaignData.toJsonForSubmit());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.campaignSuccessCreated), 
              backgroundColor: Colors.green
            ),
          );
          // YENİ: KDS atama kontrolü ve yönlendirme mantığı
          await _handlePostCampaignCreation(context);
        }
      } else {
        await CampaignService.updateCampaign(widget.token, widget.campaignMenu!.id, campaignData.toJsonForSubmit());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.campaignSuccessUpdated), 
              backgroundColor: Colors.green
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessageKey = "campaignErrorSubmit|${e.toString().replaceFirst("Exception: ", "")}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // build metodunun geri kalanı aynı kalabilir, bu yüzden kısaltıldı.
    // ... (build metodunun içeriği burada)
    final l10n = AppLocalizations.of(context)!;
    String displayErrorMessage = '';
    if (_errorMessageKey.isNotEmpty) {
        final parts = _errorMessageKey.split('|');
        final key = parts[0];
        final details = parts.length > 1 ? parts[1] : '';
        switch (key) {
            case "errorLoadingDataWithDetails": displayErrorMessage = l10n.errorLoadingDataWithDetails(details); break;
            case "campaignErrorAddItem": displayErrorMessage = l10n.campaignErrorAddItem; break;
            case "errorUploadingPhotoWithDetails": displayErrorMessage = l10n.errorUploadingPhotoWithDetails(details); break;
            case "campaignErrorSubmit": displayErrorMessage = l10n.campaignErrorSubmit(details); break;
        }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.campaignMenu == null ? l10n.addCampaignTitle : l10n.editCampaignTitle, 
          style: const TextStyle(color: Colors.white)
        ),
          flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
             colors: [Colors.blue.shade900.withOpacity(0.9), Colors.blue.shade400.withOpacity(0.8)],
             begin: Alignment.topLeft, end: Alignment.bottomRight,
           ),
          ),
        child: _isLoadingMenuItems
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Card(
                    color: Colors.white.withOpacity(0.9),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(controller: _nameController, decoration: InputDecoration(labelText: l10n.campaignNameLabel, border: const OutlineInputBorder()), validator: (v) => (v == null || v.isEmpty) ? l10n.validatorRequiredField : null),
                          const SizedBox(height: 12),
                          TextFormField(controller: _descriptionController, decoration: InputDecoration(labelText: l10n.campaignDescriptionLabel, border: const OutlineInputBorder()), maxLines: 2),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _campaignPriceController,
                            decoration: InputDecoration(labelText: l10n.campaignPriceLabel, prefixText: l10n.currencyTL, border: const OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                            validator: (v) => (v == null || v.isEmpty || (double.tryParse(v) ?? -1) <=0 ) ? l10n.validatorInvalidPositivePrice : null
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(title: Text(l10n.campaignActiveLabel), value: _isActive, onChanged: (val) => setState(()=> _isActive = val), activeColor: Theme.of(context).primaryColor),
                          const SizedBox(height: 12),
                          Row(children: [Expanded(child: Text(_startDate == null ? l10n.campaignNoStartDate : l10n.campaignStartDateLabel(DateFormat('dd/MM/yyyy').format(_startDate!)))), IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async { final date = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if(date != null && mounted) setState(()=>_startDate = date);})]),
                          Row(children: [Expanded(child: Text(_endDate == null ? l10n.campaignNoEndDate : l10n.campaignEndDateLabel(DateFormat('dd/MM/yyyy').format(_endDate!)))), IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async { final date = await showDatePicker(context: context, initialDate: _endDate ?? _startDate ?? DateTime.now(), firstDate: _startDate ?? DateTime(2000), lastDate: DateTime(2100)); if(date != null && mounted) setState(()=>_endDate = date);})]),
                          const SizedBox(height: 10),
                            Center(child: _buildImagePreview(l10n)),
                            TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image), label: Text(l10n.campaignSelectImageButton)),
                          const SizedBox(height: 16),
                          const Divider(),
                          Text(l10n.campaignContentTitle(_calculatedNormalTotal.toStringAsFixed(2), l10n.currencySymbol), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_selectedCampaignItems.isEmpty) Text(l10n.campaignNoProductsAdded),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _selectedCampaignItems.length,
                            itemBuilder: (ctx, index) {
                              final campaignItem = _selectedCampaignItems[index];
                              return ListTile(
                                leading: const Icon(Icons.shopping_basket_outlined),
                                title: Text("${campaignItem.menuItemName ?? l10n.unknownProduct} ${campaignItem.variantName != null ? '(${campaignItem.variantName})' : ''}"),
                                subtitle: Text(l10n.campaignItemDetails(campaignItem.quantity.toString(), campaignItem.originalPrice?.toStringAsFixed(2) ?? 'N/A', l10n.currencySymbol)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () {
                                    if(mounted) {
                                      setState(() {
                                        _selectedCampaignItems.removeAt(index);
                                        _recalculateNormalTotal();
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add_shopping_cart),
                            label: Text(l10n.campaignAddProductButton),
                            onPressed: _isLoadingMenuItems ? null : _openAddItemDialog,
                          ),
                          const SizedBox(height: 20),
                          if (displayErrorMessage.isNotEmpty) Text(displayErrorMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submitCampaign,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12)
                            ),
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(widget.campaignMenu == null ? l10n.campaignCreateButton : l10n.campaignUpdateButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
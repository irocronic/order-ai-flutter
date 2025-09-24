// lib/widgets/setup_wizard/menu_items/components/manual_form_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

import '../../../../services/user_session.dart';
import '../services/menu_item_service.dart';
import '../models/menu_item_form_data.dart';
import '../dialogs/limit_reached_dialog.dart';
import 'image_picker_widget.dart';

class ManualFormSection extends StatefulWidget {
  final String token;
  final int businessId;
  final List<dynamic> availableCategories;
  final bool isLoadingScreenData;
  final VoidCallback onMenuItemAdded;
  final Function(String, {bool isError}) onMessageChanged;

  const ManualFormSection({
    Key? key,
    required this.token,
    required this.businessId,
    required this.availableCategories,
    required this.isLoadingScreenData,
    required this.onMenuItemAdded,
    required this.onMessageChanged,
  }) : super(key: key);

  @override
  State<ManualFormSection> createState() => _ManualFormSectionState();
}

class _ManualFormSectionState extends State<ManualFormSection>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final MenuItemService _menuItemService = MenuItemService();
  final MenuItemFormData _formData = MenuItemFormData();
  
  bool _isSubmitting = false;
  bool _isExpanded = false; // Collapse/expand state
  
  // Reçeteli ürün özelliği için değişkenler
  bool _isFromRecipe = true; 
  final TextEditingController _priceController = TextEditingController(); // Reçetesiz ürün fiyatı için

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _formData.dispose();
    _priceController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Toggle expand/collapse
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _formData.selectedCategoryId = categoryId;
      if (categoryId != null) {
        final selectedCategory = widget.availableCategories.firstWhereOrNull(
          (cat) => cat['id'] == categoryId,
        );
        if (selectedCategory != null && selectedCategory['kdv_rate'] != null) {
          _formData.kdvController.text = selectedCategory['kdv_rate'].toString();
        } else {
          _formData.kdvController.text = '10.0';
        }
      } else {
        _formData.kdvController.text = '10.0';
      }
    });
  }

  void _clearForm() {
    _formData.clear();
    _priceController.clear();
    setState(() {
      _isFromRecipe = true; // Varsayılan değere dön
    });
  }

  Future<void> _addMenuItem() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_formData.selectedCategoryId == null && widget.availableCategories.isNotEmpty) {
      widget.onMessageChanged(l10n.setupMenuItemsErrorSelectCategory, isError: true);
      return;
    }

    final currentLimits = UserSession.limitsNotifier.value;
    if (await _menuItemService.getCurrentMenuItemCount(widget.token) >= currentLimits.maxMenuItems) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => LimitReachedDialog(
            title: l10n.dialogLimitReachedTitle,
            message: l10n.createMenuItemErrorLimitExceeded(currentLimits.maxMenuItems.toString()),
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _menuItemService.createMenuItemSmart(
        token: widget.token,
        businessId: widget.businessId,
        formData: _formData,
        isFromRecipe: _isFromRecipe,
        price: _isFromRecipe ? null : double.tryParse(_priceController.text.replaceAll(',', '.')),
        l10n: l10n,
      );

      if (mounted) {
        widget.onMessageChanged(l10n.setupMenuItemsSuccessAdded(_formData.nameController.text.trim()));
        _clearForm();
        FocusScope.of(context).unfocus();
        widget.onMenuItemAdded();
      }
    } catch (e) {
      if (mounted) {
        widget.onMessageChanged(
          l10n.errorUploadingPhotoGeneral(e.toString().replaceFirst("Exception: ", "")),
          isError: true
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Collapsible Header
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined, 
                    color: Colors.white.withOpacity(0.8), 
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.manualMenuItemAddTitle, // GÜNCELLENDİ
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white.withOpacity(0.9)
                      ),
                    ),
                  ),
                  // Expand/Collapse icon with animation
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.8),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Animated collapsible content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Divider line
                    Divider(
                      color: Colors.white.withOpacity(0.3),
                      height: 1,
                      thickness: 1,
                    ),
                    const SizedBox(height: 16),
                    
                    // Kategori Dropdown
                    _buildCategoryDropdown(inputDecoration, textStyle, l10n),
                    const SizedBox(height: 16),
                    
                    // Ürün Adı
                    TextFormField(
                      controller: _formData.nameController,
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
                    
                    // Açıklama
                    TextFormField(
                      controller: _formData.descriptionController,
                      style: textStyle,
                      decoration: inputDecoration.copyWith(
                        labelText: l10n.setupMenuItemsDescriptionLabel,
                        prefixIcon: const Icon(Icons.description_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    
                    // KDV Oranı
                    TextFormField(
                      controller: _formData.kdvController,
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
                    
                    // Reçeteli/Reçetesiz ürün seçimi
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: Text(
                              l10n.menuItemIsFromRecipeLabel,
                              style: textStyle.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              _isFromRecipe
                                  ? l10n.menuItemIsFromRecipeSubtitleYes
                                  : l10n.menuItemIsFromRecipeSubtitleNo,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                            value: _isFromRecipe,
                            onChanged: (bool value) {
                              setState(() {
                                _isFromRecipe = value;
                                if (value) {
                                  _priceController.clear();
                                }
                              });
                            },
                            activeColor: Colors.lightBlueAccent,
                            inactiveTrackColor: Colors.white.withOpacity(0.3),
                            contentPadding: EdgeInsets.zero,
                          ),
                          
                          // Reçetesiz ürün için fiyat alanı
                          if (!_isFromRecipe) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _priceController,
                              style: textStyle,
                              decoration: inputDecoration.copyWith(
                                labelText: l10n.menuItemPriceLabel,
                                prefixText: l10n.currencySymbol, // GÜNCELLENDİ
                                prefixIcon: const Icon(Icons.monetization_on_outlined),
                                hintText: l10n.menuItemPriceHint, // GÜNCELLENDİ
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))],
                              validator: (value) {
                                if (!_isFromRecipe && (value == null || value.trim().isEmpty)) {
                                  return l10n.validatorRequiredField;
                                }
                                if (value != null && value.isNotEmpty) {
                                  final price = double.tryParse(value.trim().replaceAll(',', '.'));
                                  if (price == null || price < 0) {
                                    return l10n.validatorInvalidNumber;
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Resim Picker
                    ImagePickerWidget(
                      onImageChanged: (imageFile, imageBytes) {
                        _formData.setImage(imageFile, imageBytes);
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox.shrink()
                          : const Icon(Icons.add_circle_outline),
                      label: _isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, 
                                color: Colors.blue.shade900
                              ))
                          : Text(l10n.setupMenuItemsAddButton),
                      onPressed: _isSubmitting || (widget.isLoadingScreenData && widget.availableCategories.isEmpty)
                          ? null
                          : _addMenuItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.95),
                        foregroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(InputDecoration inputDecoration, TextStyle textStyle, AppLocalizations l10n) {
    if (widget.isLoadingScreenData && widget.availableCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(l10n.setupMenuItemsLoadingCategories, style: textStyle)
        )
      );
    }
    
    if (widget.availableCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            l10n.setupMenuItemsErrorCreateCategoryFirst,
            style: const TextStyle(color: Colors.orangeAccent)
          )
        )
      );
    }
    
    return DropdownButtonFormField<int>(
      value: _formData.selectedCategoryId,
      style: textStyle,
      dropdownColor: Colors.blue.shade800,
      iconEnabledColor: Colors.white70,
      isExpanded: true,
      decoration: inputDecoration.copyWith(
        labelText: l10n.setupMenuItemsSelectCategoryLabel,
        prefixIcon: const Icon(Icons.category_outlined),
      ),
      items: widget.availableCategories.map<DropdownMenuItem<int>>((category) {
        return DropdownMenuItem<int>(
          value: category['id'],
          child: Text(
            category['name'] ?? l10n.unknownCategory,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _onCategoryChanged,
      validator: (value) => value == null ? l10n.setupMenuItemsSelectCategoryValidator : null,
    );
  }
}
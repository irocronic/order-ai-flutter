// lib/widgets/setup_wizard/categories/components/manual_form_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

import '../../../../models/kds_screen_model.dart';
import '../../../../services/user_session.dart';
import '../services/category_service.dart';
import '../models/category_form_data.dart';
import '../dialogs/limit_reached_dialog.dart';
import 'image_picker_widget.dart';

class ManualFormSection extends StatefulWidget {
  final String token;
  final int businessId;
  final List<dynamic> categories;
  final List<KdsScreenModel> availableKdsScreens;
  final bool isLoadingScreenData;
  final VoidCallback onCategoryAdded;
  final Function(String, {bool isError}) onMessageChanged;

  const ManualFormSection({
    Key? key,
    required this.token,
    required this.businessId,
    required this.categories,
    required this.availableKdsScreens,
    required this.isLoadingScreenData,
    required this.onCategoryAdded,
    required this.onMessageChanged,
  }) : super(key: key);

  @override
  State<ManualFormSection> createState() => _ManualFormSectionState();
}

class _ManualFormSectionState extends State<ManualFormSection>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final CategoryService _categoryService = CategoryService();
  final CategoryFormData _formData = CategoryFormData();
  
  bool _isSubmitting = false;
  bool _isExpanded = false;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _updateKdsSelection();
    
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ManualFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableKdsScreens != widget.availableKdsScreens) {
      _updateKdsSelection();
    }
  }

  void _updateKdsSelection() {
    if (widget.availableKdsScreens.length == 1) {
      _formData.selectedKdsScreenId = widget.availableKdsScreens.first.id;
    } else {
      _formData.selectedKdsScreenId = null;
    }
  }

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

  Future<void> _addCategory() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;
    final currentLimits = UserSession.limitsNotifier.value;
    if (widget.categories.length >= currentLimits.maxCategories) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => LimitReachedDialog(
            title: l10n.dialogLimitReachedTitle,
            message: l10n.createCategoryErrorLimitExceeded(currentLimits.maxCategories.toString()),
          ),
        );
      }
      return;
    }

    if (widget.availableKdsScreens.isNotEmpty && _formData.selectedKdsScreenId == null) {
      widget.onMessageChanged(l10n.setupCategoriesErrorSelectKds, isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _categoryService.createCategory(
        token: widget.token,
        businessId: widget.businessId,
        formData: _formData,
      );

      if (mounted) {
        widget.onMessageChanged(l10n.setupCategoriesSuccessAdded(_formData.nameController.text.trim()));
        _formData.clear();
        _updateKdsSelection();
        FocusScope.of(context).unfocus();
        widget.onCategoryAdded();
      }
    } catch (e) {
      if (mounted) {
        widget.onMessageChanged(
          l10n.setupCategoriesErrorCreating(e.toString().replaceFirst("Exception: ", "")),
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
                      l10n.setupCategoriesManualAddTitle,
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white.withOpacity(0.9)
                      ),
                    ),
                  ),
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
          
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(
                      color: Colors.white.withOpacity(0.3),
                      height: 1,
                      thickness: 1,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _formData.nameController,
                      style: textStyle,
                      decoration: inputDecoration.copyWith(
                        labelText: l10n.categoryNameLabelRequired,
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? l10n.categoryNameValidator
                          : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _formData.kdvController,
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
                      value: _formData.selectedParentCategory,
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
                          child: Text(l10n.setupCategoriesMainCategory, style: textStyle)
                        ),
                        ...widget.categories
                            .where((cat) => cat['parent'] == null)
                            .map<DropdownMenuItem<dynamic>>((category) {
                          return DropdownMenuItem<dynamic>(
                            value: category,
                            child: Text(
                              category['name'] ?? l10n.unknownCategory,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) => setState(() => _formData.selectedParentCategory = value),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildKdsDropdown(inputDecoration, textStyle, l10n),
                    const SizedBox(height: 16),
                    
                    ImagePickerWidget(
                      onImageChanged: (imageFile, imageBytes) {
                        _formData.setImage(imageFile, imageBytes);
                      },
                    ),
                    const SizedBox(height: 24),
                    
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
                          : Text(l10n.setupCategoriesAddButton),
                      onPressed: _isSubmitting || (widget.isLoadingScreenData && widget.availableKdsScreens.isEmpty)
                          ? null
                          : _addCategory,
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

  Widget _buildKdsDropdown(InputDecoration inputDecoration, TextStyle textStyle, AppLocalizations l10n) {
    if (widget.isLoadingScreenData && widget.availableKdsScreens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(l10n.setupCategoriesKdsLoading, style: textStyle)
        )
      );
    }
    
    if (widget.availableKdsScreens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            l10n.setupCategoriesErrorDefineKdsFirst,
            style: const TextStyle(color: Colors.orangeAccent)
          )
        )
      );
    }
    
    return DropdownButtonFormField<int?>(
      isExpanded: true,
      value: _formData.selectedKdsScreenId,
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
          child: Text(l10n.setupCategoriesHintSelectKds, style: textStyle)
        ),
        ...widget.availableKdsScreens.map<DropdownMenuItem<int?>>((kds) {
          return DropdownMenuItem<int?>(
            value: kds.id,
            child: Text(kds.name, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
      ],
      validator: (value) {
        if (widget.availableKdsScreens.isNotEmpty && value == null) {
          return l10n.setupCategoriesValidatorSelectKds;
        }
        return null;
      },
      onChanged: (value) => setState(() => _formData.selectedKdsScreenId = value),
    );
  }
}
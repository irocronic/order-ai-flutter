// lib/widgets/setup_wizard/menu_items/dialogs/variant_management_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../models/menu_item_variant.dart';
import '../../../../services/firebase_storage_service.dart';
import '../../../../utils/currency_formatter.dart';
import '../models/variant_template_config.dart';
import '../components/image_picker_widget.dart';
import '../utils/icon_utils.dart';

class VariantManagementDialog extends StatefulWidget {
  final int templateId;
  final VariantTemplateConfig variantConfig;
  final List<dynamic> variantTemplates;
  final bool isLoadingVariantTemplates;
  final int businessId;
  final Function(Map<String, dynamic>) onVariantTemplateSelected;

  const VariantManagementDialog({
    Key? key,
    required this.templateId,
    required this.variantConfig,
    required this.variantTemplates,
    required this.isLoadingVariantTemplates,
    required this.businessId,
    required this.onVariantTemplateSelected,
  }) : super(key: key);

  @override
  State<VariantManagementDialog> createState() => _VariantManagementDialogState();
}

class _VariantManagementDialogState extends State<VariantManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addVariant() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final variantName = widget.variantConfig.variantNameController.text.trim();
    final priceText = widget.variantConfig.variantPriceController.text.trim();
    
    if (variantName.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.snackbarVariantNameAndPriceRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final price = double.tryParse(priceText.replaceAll(',', '.'));
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.snackbarInvalidPrice),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fotoğraf zorunlu kontrolü
    if (widget.variantConfig.hasVariantImageEnabled && !widget.variantConfig.hasVariantImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.snackbarVariantPhotoRequiredWhenActive),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Fotoğraf varsa hemen upload et
    String variantImageUrl = '';
    if (widget.variantConfig.hasVariantImageEnabled && widget.variantConfig.hasVariantImage) {
      try {
        setState(() => _isUploading = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text(l10n.snackbarUploadingVariantPhoto),
              ],
            ),
            duration: const Duration(seconds: 30),
          ),
        );

        variantImageUrl = await _uploadVariantImageNow(variantName);
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        print('✅ Varyant fotoğrafı başarıyla upload edildi: $variantImageUrl');
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackbarPhotoUploadFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isUploading = false);
        return;
      } finally {
        setState(() => _isUploading = false);
      }
    }

    final newVariant = MenuItemVariant(
      id: -DateTime.now().millisecondsSinceEpoch - widget.variantConfig.variants.length,
      menuItem: 0,
      name: variantName,
      price: price,
      isExtra: widget.variantConfig.isVariantExtra,
      image: variantImageUrl,
    );

    setState(() {
      widget.variantConfig.addVariant(newVariant);
      widget.variantConfig.clearVariantForm();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.snackbarVariantAdded(variantName)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String> _uploadVariantImageNow(String variantName) async {
    String fileName;
    if (widget.variantConfig.variantImageXFile != null) {
      fileName = p.basename(widget.variantConfig.variantImageXFile!.path);
    } else {
      final safeVariantName = variantName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      fileName = 'variant_${safeVariantName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    
    String firebaseFileName = "business_${widget.businessId}/variants/${DateTime.now().millisecondsSinceEpoch}_$fileName";
    
    final imageUrl = await FirebaseStorageService.uploadImage(
      imageFile: widget.variantConfig.variantImageXFile != null 
          ? File(widget.variantConfig.variantImageXFile!.path) 
          : null,
      imageBytes: widget.variantConfig.variantWebImageBytes,
      fileName: firebaseFileName,
      folderPath: 'variant_images',
    );
    
    if (imageUrl == null) {
      throw Exception(AppLocalizations.of(context)!.firebaseUploadFailed);
    }
    
    return imageUrl;
  }

  void _removeVariant(int variantId) {
    setState(() {
      widget.variantConfig.removeVariant(variantId);
    });
  }

  void _toggleVariantExtra(bool isExtra) {
    setState(() {
      widget.variantConfig.isVariantExtra = isExtra;
    });
  }

  void _toggleVariantPhoto(bool hasPhoto) {
    setState(() {
      widget.variantConfig.hasVariantImageEnabled = hasPhoto;
      if (!hasPhoto) {
        widget.variantConfig.setVariantImage(null, null);
      }
    });
  }

  bool get _hasUnfinishedVariantData {
    final nameText = widget.variantConfig.variantNameController.text.trim();
    final priceText = widget.variantConfig.variantPriceController.text.trim();
    return nameText.isNotEmpty || priceText.isNotEmpty;
  }

  void _onCompletePressed() {
    if (_hasUnfinishedVariantData) {
      _showUnfinishedVariantWarning();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _showUnfinishedVariantWarning() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
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
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient and glass effect
                Container(
                  padding: const EdgeInsets.all(24.0),
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
                      topLeft: Radius.circular(20.0),
                      topRight: Radius.circular(20.0),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade300,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Title
                      Text(
                        l10n.dialogPendingVariantTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Content
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    children: [
                      // Message
                      Text(
                        l10n.dialogPendingVariantContent1,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Pending data highlight
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.variantConfig.variantNameController.text.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.label_outline,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.dialogPendingVariantContentName(widget.variantConfig.variantNameController.text.trim()),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.variantConfig.variantPriceController.text.trim().isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.monetization_on_outlined,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.dialogPendingVariantContentPrice(widget.variantConfig.variantPriceController.text.trim()),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Additional message
                      Text(
                        l10n.dialogPendingVariantContent2,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Actions
                Container(
                  padding: const EdgeInsets.all(24.0),
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
                      bottomLeft: Radius.circular(20.0),
                      bottomRight: Radius.circular(20.0),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  child: Column(
                    children: [
                      // First row: Cancel and Delete buttons
                      Row(
                        children: [
                          // Cancel button
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withOpacity(0.9),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      l10n.dialogButtonCancel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Delete and exit button
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                setState(() {
                                  widget.variantConfig.clearVariantForm();
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.snackbarPendingVariantDataCleared),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade300,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red.shade300,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      l10n.dialogButtonDeleteAndExit,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Second row: Add variant button (full width)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _addVariant();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l10n.buttonAddVariant,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomCheckbox({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool enabled,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: GestureDetector(
        onTap: enabled ? () => onChanged(!value) : null,
        behavior: HitTestBehavior.translucent,
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(
                  color: enabled 
                      ? Colors.white.withOpacity(0.7) 
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                color: value 
                    ? (enabled ? Colors.white : Colors.white.withOpacity(0.3))
                    : Colors.transparent,
              ),
              child: value 
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: enabled ? Colors.blue.shade800 : Colors.blue.shade800.withOpacity(0.5),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: enabled 
                          ? Colors.white.withOpacity(0.7) 
                          : Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencySymbol = CurrencyFormatter.currentSymbol;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    final availableHeight = screenHeight - keyboardHeight - 100.0;
    final double dialogHeight = availableHeight > 600.0 ? availableHeight : 600.0;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? screenWidth * 0.15 : 16.0,
        vertical: keyboardHeight > 0 ? 8.0 : 24.0,
      ),
      child: Container(
        width: screenWidth > 600 ? 800 : double.infinity,
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
                      l10n.variantManagementDialogTitle(widget.variantConfig.templateName),
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
                      onPressed: _isUploading ? null : () {
                        if (_hasUnfinishedVariantData) {
                          _showUnfinishedVariantWarning();
                        } else {
                          Navigator.of(context).pop(true);
                        }
                      },
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
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 6.0,
                  radius: const Radius.circular(3),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hızlı Varyant Ekleme
                        if (widget.variantTemplates.isNotEmpty) ...[
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
                                        color: Colors.yellow.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.flash_on, 
                                        color: Colors.yellow.shade300, 
                                        size: 20
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l10n.quickAddVariantTitle,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (widget.isLoadingVariantTemplates) ...[
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (widget.isLoadingVariantTemplates)
                                  Center(
                                    child: Text(
                                      l10n.loadingVariantTemplates,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7), 
                                        fontSize: 14
                                      ),
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 8.0,
                                    children: widget.variantTemplates.take(12).map<Widget>((variantTemplate) {
                                      final variantName = variantTemplate['name'] as String;
                                      final isUsed = widget.variantConfig.variants.any((variant) => 
                                        variant.name.toLowerCase() == variantName.toLowerCase()
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
                                            onTap: isUsed || _isUploading ? null : () {
                                              widget.onVariantTemplateSelected(variantTemplate);
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    IconUtils.getIconFromName(variantTemplate['icon_name'] ?? 'label_outline'),
                                                    size: 16,
                                                    color: isUsed 
                                                        ? Colors.white.withOpacity(0.5) 
                                                        : Colors.white,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      variantName,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: isUsed 
                                                            ? Colors.white.withOpacity(0.5) 
                                                            : Colors.white,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
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
                          const SizedBox(height: 20),
                        ],
                        
                        // Mevcut Varyantlar
                        if (widget.variantConfig.variants.isNotEmpty) ...[
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
                                    Flexible(
                                      child: Text(
                                        l10n.addedVariantsTitle(widget.variantConfig.variants.length),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...widget.variantConfig.variants.asMap().entries.map((entry) {
                                  final variant = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
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
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 8.0,
                                                runSpacing: 4.0,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '$currencySymbol${variant.price.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white.withOpacity(0.9),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  if (variant.isExtra)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.withOpacity(0.3),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        l10n.variantExtraTag,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.orange.shade200,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  if (variant.image.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withOpacity(0.3),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.camera_alt, color: Colors.blue.shade200, size: 10),
                                                          const SizedBox(width: 2),
                                                          Text(
                                                            l10n.variantWithPhotoTag,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors.blue.shade200,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _isUploading ? null : () => _removeVariant(variant.id),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: _isUploading ? Colors.red.shade300.withOpacity(0.5) : Colors.red.shade300,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        // Manuel Varyant Ekleme Formu
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
                                    Flexible(
                                      child: Text(
                                        l10n.manualAddVariantTitle,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Varyant adı ve fiyat
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth < 400) {
                                      return Column(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                                            ),
                                            child: TextFormField(
                                              controller: widget.variantConfig.variantNameController,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: l10n.variantNameLabel,
                                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                                hintText: l10n.variantNameHint,
                                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              ),
                                              validator: (v) => (v == null || v.isEmpty) ? l10n.validatorVariantNameRequired : null,
                                              enabled: !_isUploading,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                                            ),
                                            child: TextFormField(
                                              controller: widget.variantConfig.variantPriceController,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: l10n.variantPriceLabel,
                                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                                prefixText: currencySymbol,
                                                prefixStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                                border: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              ),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))
                                              ],
                                              validator: (v) {
                                                if (v == null || v.isEmpty) return l10n.validatorPriceRequired;
                                                if (double.tryParse(v.replaceAll(',', '.')) == null) return l10n.validatorInvalidPrice;
                                                return null;
                                              },
                                              enabled: !_isUploading,
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Row(
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
                                                controller: widget.variantConfig.variantNameController,
                                                style: const TextStyle(color: Colors.white),
                                                decoration: InputDecoration(
                                                  labelText: l10n.variantNameLabel,
                                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                                  hintText: l10n.variantNameHint,
                                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                ),
                                                validator: (v) => (v == null || v.isEmpty) ? l10n.validatorVariantNameRequired : null,
                                                enabled: !_isUploading,
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
                                                controller: widget.variantConfig.variantPriceController,
                                                style: const TextStyle(color: Colors.white),
                                                decoration: InputDecoration(
                                                  labelText: l10n.variantPriceLabel,
                                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                                  prefixText: currencySymbol,
                                                  prefixStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                ),
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}'))
                                                ],
                                                validator: (v) {
                                                  if (v == null || v.isEmpty) return l10n.validatorPriceRequired;
                                                  if (double.tryParse(v.replaceAll(',', '.')) == null) return l10n.validatorInvalidPrice;
                                                  return null;
                                                },
                                                enabled: !_isUploading,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                
                                // Seçenekler
                                Column(
                                  children: [
                                    _buildCustomCheckbox(
                                      title: l10n.checkboxExtraOptionTitle,
                                      subtitle: l10n.checkboxExtraOptionSubtitle,
                                      value: widget.variantConfig.isVariantExtra,
                                      onChanged: _toggleVariantExtra,
                                      enabled: !_isUploading,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildCustomCheckbox(
                                      title: l10n.checkboxAddPhotoTitle,
                                      subtitle: l10n.checkboxAddPhotoSubtitle,
                                      value: widget.variantConfig.hasVariantImageEnabled,
                                      onChanged: _toggleVariantPhoto,
                                      enabled: !_isUploading,
                                    ),
                                  ],
                                ),
                                
                                // Fotoğraf yükleme alanı
                                if (widget.variantConfig.hasVariantImageEnabled) ...[
                                  const SizedBox(height: 16),
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
                                                l10n.variantPhotoTitle,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            if (widget.variantConfig.hasVariantImage)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  l10n.statusSelected,
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
                                        Stack(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                                              ),
                                              child: ImagePickerWidget(
                                                isCompact: false,
                                                initialImageFile: widget.variantConfig.variantImageXFile,
                                                initialImageBytes: widget.variantConfig.variantWebImageBytes,
                                                onImageChanged: _isUploading 
                                                    ? (xFile, bytes) {}
                                                    : (xFile, bytes) {
                                                        setState(() {
                                                          widget.variantConfig.setVariantImage(xFile, bytes);
                                                        });
                                                      },
                                              ),
                                            ),
                                            if (_isUploading)
                                              Container(
                                                width: double.infinity,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.5),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Center(
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 20),
                                
                                // Ekle butonu
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isUploading ? null : _addVariant,
                                    icon: _isUploading 
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
                                      _isUploading ? l10n.statusUploading : l10n.buttonAddVariant,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isUploading ? Colors.white.withOpacity(0.3) : Colors.white,
                                      foregroundColor: _isUploading ? Colors.white.withOpacity(0.5) : Colors.blue.shade700,
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
            
            // Footer/Actions with gradient - Responsive footer
            Container(
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Responsive button layout
                    return IntrinsicHeight(
                      child: Row(
                        children: [
                          // Close button
                          Expanded(
                            flex: 2,
                            child: TextButton(
                              onPressed: _isUploading ? null : () {
                                if (_hasUnfinishedVariantData) {
                                  _showUnfinishedVariantWarning();
                                } else {
                                  Navigator.of(context).pop(true);
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withOpacity(0.9),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  l10n.buttonClose,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Complete button
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              onPressed: _isUploading ? null : _onCompletePressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green.shade700,
                                disabledBackgroundColor: Colors.white.withOpacity(0.3),
                                disabledForegroundColor: Colors.white.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 4,
                                shadowColor: Colors.black.withOpacity(0.3),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        l10n.buttonComplete(widget.variantConfig.variants.length),
                                        style: const TextStyle(
                                          fontSize: 13,
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
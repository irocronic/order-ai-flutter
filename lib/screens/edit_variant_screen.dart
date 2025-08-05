// lib/screens/edit_variant_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/menu_item_variant.dart';
import '../services/api_service.dart';
import '../services/firebase_storage_service.dart';

class EditVariantScreen extends StatefulWidget {
  final String token;
  final MenuItemVariant variant;
  final VoidCallback onVariantUpdated;

  const EditVariantScreen({
    Key? key,
    required this.token,
    required this.variant,
    required this.onVariantUpdated,
  }) : super(key: key);

  @override
  _EditVariantScreenState createState() => _EditVariantScreenState();
}

class _EditVariantScreenState extends State<EditVariantScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late bool _isExtra;
  bool _isSubmitting = false;
  String _messageCode = '';

  XFile? _pickedImageXFile;
  Uint8List? _webImageBytes;
  String? _currentImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.variant.name);
    _priceController = TextEditingController(text: widget.variant.price.toString());
    _isExtra = widget.variant.isExtra;
    _currentImageUrl = widget.variant.image;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        _webImageBytes = await image.readAsBytes();
        _pickedImageXFile = null;
      } else {
        _pickedImageXFile = image;
        _webImageBytes = null;
      }
      setState(() {});
    }
  }

  Widget _buildCurrentImage(AppLocalizations l10n) {
    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(_webImageBytes!, height: 150, width: 150, fit: BoxFit.cover);
    } else if (!kIsWeb && _pickedImageXFile != null) {
      return Image.file(File(_pickedImageXFile!.path), height: 150, width: 150, fit: BoxFit.cover);
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
       if (_currentImageUrl!.startsWith('http')) {
        return Image.network(
          _currentImageUrl!,
          height: 150, width: 150, fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
          },
        );
      } else {
          return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
      }
    }
    return Text(l10n.variantPhotoNotUploaded, style: const TextStyle(color: Colors.black54));
  }

  Future<void> _updateVariant() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _messageCode = '';
    });

    String? finalImageUrl = _currentImageUrl;

    if (_pickedImageXFile != null || _webImageBytes != null) {
      try {
        String originalFileName = _pickedImageXFile != null
            ? p.basename(_pickedImageXFile!.path)
            : 'variant_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String safeFileName = "menu_${widget.variant.menuItem}_variant_${widget.variant.id}_${Uri.encodeComponent(originalFileName)}";

        finalImageUrl = await FirebaseStorageService.uploadImage(
          imageFile: _pickedImageXFile != null ? File(_pickedImageXFile!.path) : null,
          imageBytes: _webImageBytes,
          fileName: safeFileName,
          folderPath: 'variant_images',
        );

        if (finalImageUrl == null) {
          if (mounted) {
            setState(() {
              _messageCode = "UPLOAD_ERROR";
              _isSubmitting = false;
            });
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messageCode = "UPLOAD_GENERAL_ERROR|${e.toString()}";
            _isSubmitting = false;
          });
        }
        return;
      }
    }

    try {
      final Map<String, dynamic> payload = {
        'menu_item': widget.variant.menuItem,
        'name': _nameController.text,
        'price': (double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0).toString(),
        'is_extra': _isExtra,
        'image': finalImageUrl,
      };

      final response = await http.put(
        ApiService.getUrl('/menu-item-variants/${widget.variant.id}/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}"
        },
        body: jsonEncode(payload),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          widget.onVariantUpdated();
          Navigator.pop(context, true);
        } else {
          setState(() {
            _messageCode = "UPDATE_API_ERROR|${response.statusCode}|${utf8.decode(response.bodyBytes)}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messageCode = "UPDATE_GENERAL_ERROR|${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    String displayMessage = '';
    Color messageColor = Colors.red.shade700;

    if(_messageCode.isNotEmpty) {
        final parts = _messageCode.split('|');
        final code = parts[0];
        switch(code) {
            case 'UPDATE_API_ERROR':
                displayMessage = l10n.errorUpdatingVariant(parts.length > 1 ? parts[1] : '', parts.length > 2 ? parts[2] : '');
                break;
            case 'UPDATE_GENERAL_ERROR':
                 displayMessage = l10n.errorUpdatingVariantGeneral(parts.length > 1 ? parts[1] : '');
                 break;
            case 'UPLOAD_ERROR':
                displayMessage = l10n.errorUploadingPhoto;
                break;
            case 'UPLOAD_GENERAL_ERROR':
                displayMessage = l10n.errorUploadingPhotoGeneral(parts.length > 1 ? parts[1] : '');
                break;
            default:
                displayMessage = _messageCode;
        }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.editVariantPageTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF283593), Color(0xFF455A64)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.white.withOpacity(0.85),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: _buildCurrentImage(l10n)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.indigo),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(l10n.buttonChangePhoto),
                            onPressed: _pickImage,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: l10n.variantNameLabel,
                              labelStyle: const TextStyle(color: Colors.black54),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.7),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.variantNameValidator;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _priceController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: l10n.variantPriceLabel,
                              labelStyle: const TextStyle(color: Colors.black54),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.7),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.variantPriceValidator;
                              }
                              if (double.tryParse(value.replaceAll(',', '.')) == null) {
                                return l10n.variantPriceValidatorInvalid;
                              }
                              return null;
                            },
                          ),
                           CheckboxListTile(
                            title: Text(l10n.variantIsExtraLabel, style: const TextStyle(color: Colors.black87)),
                            value: _isExtra,
                            onChanged: (bool? newVal) {
                              setState(() {
                                _isExtra = newVal ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.indigo,
                            tileColor: Colors.white.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isSubmitting ? null : _updateVariant,
                            child: _isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                : Text(l10n.updateButton, style: const TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(height: 16),
                          if (displayMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top:10.0),
                              child: Text(
                                displayMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: messageColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

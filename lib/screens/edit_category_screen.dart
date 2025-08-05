// lib/screens/edit_category_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/kds_management_service.dart';
import '../models/kds_screen_model.dart';
import 'package:path/path.dart' as p;

class EditCategoryScreen extends StatefulWidget {
  final String token;
  final int businessId;
  final dynamic category;
  final VoidCallback onMenuUpdated;

  const EditCategoryScreen({
    Key? key,
    required this.token,
    required this.category,
    required this.businessId,
    required this.onMenuUpdated,
  }) : super(key: key);

  @override
  _EditCategoryScreenState createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  // YENİ: KDV oranı için TextEditingController eklendi.
  late TextEditingController _kdvController;
  dynamic _selectedParentId;
  bool _isLoadingScreenData = true;
  bool _isSubmittingCategory = false;
  String _messageCode = '';
  List<dynamic> _availableParentCategories = [];

  List<KdsScreenModel> _kdsScreensForBusiness = [];
  int? _selectedKdsScreenId;

  XFile? _pickedImageXFile;
  Uint8List? _webImageBytes;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category['name'] ?? '');
    // YENİ: KDV Controller'ı başlangıç değeriyle başlatıldı.
    _kdvController = TextEditingController(text: widget.category['kdv_rate']?.toString() ?? '10.0');
    _currentImageUrl = widget.category['image'] as String?;

    final parentData = widget.category['parent'];
    if (parentData != null) {
      if (parentData is int) {
        _selectedParentId = parentData;
      } else if (parentData is Map && parentData['id'] != null) {
        _selectedParentId = parentData['id'];
      }
    }
    
    final kdsDataFromWidget = widget.category['assigned_kds'];
    if (kdsDataFromWidget is int) {
      _selectedKdsScreenId = kdsDataFromWidget;
    } else if (kdsDataFromWidget is Map && kdsDataFromWidget['id'] is int) {
      _selectedKdsScreenId = kdsDataFromWidget['id'];
    } else {
      _selectedKdsScreenId = null;
    }
    
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingScreenData = true;
      _messageCode = '';
    });
    try {
      final results = await Future.wait([
        ApiService.fetchCategoriesForBusiness(widget.token),
        KdsManagementService.fetchKdsScreens(widget.token, widget.businessId),
      ]);

      if (mounted) {
        final categoriesData = results[0] as List<dynamic>;
        _availableParentCategories = categoriesData
            .where((cat) => cat['id'] != widget.category['id'] && cat['parent'] != widget.category['id'])
            .toList();
        if (_selectedParentId != null && !_availableParentCategories.any((cat) => cat['id'] == _selectedParentId)) {
          _selectedParentId = null;
        }

        final kdsModelsFromService = results[1] as List<KdsScreenModel>;
        _kdsScreensForBusiness = kdsModelsFromService
            .where((kds) => kds.isActive)
            .toList();
        if (_selectedKdsScreenId != null && !_kdsScreensForBusiness.any((kds) => kds.id == _selectedKdsScreenId)) {
          _selectedKdsScreenId = null;
        }
      }
    } catch (e) {
      if (mounted) {
        _messageCode = "FETCH_ERROR|${e.toString().replaceFirst("Exception: ", "")}";
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingScreenData = false);
      }
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

  Widget _buildImagePreview(AppLocalizations l10n) {
    Widget placeholder = Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400)
      ),
      child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 50),
    );

    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_webImageBytes!, height: 150, width: 150, fit: BoxFit.cover));
    } else if (!kIsWeb && _pickedImageXFile != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_pickedImageXFile!.path), height: 150, width: 150, fit: BoxFit.cover));
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      if (_currentImageUrl!.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _currentImageUrl!,
            height: 150,
            width: 150,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint("Image Network Error in _buildImagePreview for _currentImageUrl: $error");
              return placeholder;
            },
          ),
        );
      } else {
        debugPrint("Warning: _currentImageUrl is not a full HTTP URL: $_currentImageUrl");
        return placeholder;
      }
    }
    return placeholder;
  }

  Future<void> _updateCategory() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() {
      _isSubmittingCategory = true;
      _messageCode = '';
    });

    String? finalImageUrl = _currentImageUrl;

    if (_pickedImageXFile != null || _webImageBytes != null) {
      try {
        String originalFileName = _pickedImageXFile != null
            ? p.basename(_pickedImageXFile!.path)
            : 'category_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String safeFileName = "category_${widget.category['id']}_${Uri.encodeComponent(originalFileName)}";

        finalImageUrl = await FirebaseStorageService.uploadImage(
          imageFile: _pickedImageXFile != null ? File(_pickedImageXFile!.path) : null,
          imageBytes: _webImageBytes,
          fileName: safeFileName,
          folderPath: 'category_images',
        );

        if (finalImageUrl == null) {
          throw Exception(AppLocalizations.of(context)!.errorFirebaseUploadFailed);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messageCode = "UPLOAD_ERROR|${e.toString()}";
            _isSubmittingCategory = false;
          });
        }
        return;
      }
    }

    try {
      // GÜNCELLENDİ: Payload'a `kdv_rate` eklendi.
      final Map<String, dynamic> payload = {
        'business': widget.businessId,
        'name': _nameController.text.trim(),
        'image': finalImageUrl,
        'parent': _selectedParentId,
        'assigned_kds': _selectedKdsScreenId,
        'kdv_rate': double.tryParse(_kdvController.text.trim()) ?? 10.0, // YENİ
      };

      final response = await http.put(
        ApiService.getUrl('/categories/${widget.category['id']}/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}"
        },
        body: jsonEncode(payload),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _messageCode = "UPDATE_SUCCESS";
            _currentImageUrl = finalImageUrl;
            _pickedImageXFile = null;
            _webImageBytes = null;
          });
          widget.onMenuUpdated();
        } else {
            String errorDetail;
            try {
              final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
              if (decodedBody is Map && decodedBody['detail'] != null) {
                errorDetail = decodedBody['detail'];
              } else if (decodedBody is Map && decodedBody.entries.isNotEmpty) {
                final firstError = decodedBody.entries.first;
                errorDetail = "${firstError.key}: ${(firstError.value as List).first}";
              } else {
                errorDetail = utf8.decode(response.bodyBytes);
              }
            } catch (_) {
              errorDetail = utf8.decode(response.bodyBytes);
            }
            setState(() {
                _messageCode = "UPDATE_API_ERROR|${response.statusCode}|$errorDetail";
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
          _isSubmittingCategory = false;
        });
          Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _messageCode.isNotEmpty) {
            setState(() => _messageCode = '');
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    // YENİ: KDV Controller'ı dispose ediliyor.
    _kdvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    String displayMessage = '';
    Color messageColor = Colors.red.shade300;

    if(_messageCode.isNotEmpty) {
        final parts = _messageCode.split('|');
        final code = parts[0];
        switch(code) {
            case 'FETCH_ERROR':
                displayMessage = l10n.errorLoadingInitialData(parts.length > 1 ? parts[1] : '');
                break;
            case 'UPLOAD_ERROR':
                displayMessage = l10n.errorUploadingPhotoGeneral(parts.length > 1 ? parts[1] : '');
                break;
            case 'UPDATE_SUCCESS':
                displayMessage = l10n.infoCategoryUpdatedSuccess;
                messageColor = Colors.green.shade300;
                break;
            case 'UPDATE_API_ERROR':
                displayMessage = l10n.errorUpdatingCategory(parts.length > 1 ? parts[1] : '', parts.length > 2 ? parts[2] : '');
                break;
            case 'UPDATE_GENERAL_ERROR':
                displayMessage = l10n.errorUpdatingCategoryGeneral(parts.length > 1 ? parts[1] : '');
                break;
            default:
                displayMessage = _messageCode;
        }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.editCategoryPageTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                          Center(child: _buildImagePreview(l10n)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.indigo.shade700),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(l10n.buttonSelectOrChangePhoto),
                            onPressed: _pickImage,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: l10n.categoryNameLabelRequired,
                              labelStyle: const TextStyle(color: Colors.black54),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.7),
                               prefixIcon: Icon(Icons.category_outlined, color: Colors.grey.shade700)
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.categoryNameValidator;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // YENİ: KDV Oranı için TextFormField eklendi
                          TextFormField(
                            controller: _kdvController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: l10n.categoryKdvRateLabel,
                              labelStyle: const TextStyle(color: Colors.black54),
                              suffixText: '%',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.7),
                              prefixIcon: Icon(Icons.percent_outlined, color: Colors.grey.shade700)
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.kdvRateValidatorRequired;
                              }
                              final rate = double.tryParse(value.trim());
                              if (rate == null || rate < 0 || rate > 100) {
                                return l10n.kdvRateValidatorInvalid;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<dynamic>(
                            value: _selectedParentId,
                            decoration: InputDecoration(
                              labelText: l10n.parentCategoryLabel,
                              labelStyle: const TextStyle(color: Colors.black54),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.7),
                              prefixIcon: Icon(Icons.account_tree_outlined, color: Colors.grey.shade700),
                            ),
                            dropdownColor: Colors.grey[200],
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.parentCategoryHint, style: const TextStyle(color: Colors.black54)),
                              ),
                              ..._availableParentCategories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat['id'],
                                  child: Text(cat['name'] ?? l10n.unknownCategory, style: const TextStyle(color: Colors.black87)),
                                );
                              }).toList(),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedParentId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_isLoadingScreenData && _kdsScreensForBusiness.isEmpty)
                            Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(l10n.infoKdsLoading, style: const TextStyle(color: Colors.white70))))
                          else if (_kdsScreensForBusiness.isNotEmpty)
                            DropdownButtonFormField<int?>(
                              value: _selectedKdsScreenId,
                              decoration: InputDecoration(
                                labelText: l10n.kdsScreenLabel,
                                labelStyle: const TextStyle(color: Colors.black54),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.7),
                                prefixIcon: Icon(Icons.desktop_windows_outlined, color: Colors.grey.shade700),
                              ),
                              dropdownColor: Colors.grey[200],
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(l10n.kdsScreenNotSelected, style: const TextStyle(color: Colors.black54)),
                                ),
                                ..._kdsScreensForBusiness.map((kds) {
                                  return DropdownMenuItem<int?>(
                                    value: kds.id,
                                    child: Text(kds.name, style: const TextStyle(color: Colors.black87)),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedKdsScreenId = value;
                                });
                              },
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(l10n.noKdsForBusiness, style: TextStyle(color: Colors.white.withOpacity(0.7), fontStyle: FontStyle.italic)),
                            ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 5,
                            ),
                            onPressed: _isLoadingScreenData || _isSubmittingCategory ? null : _updateCategory,
                            child: _isSubmittingCategory
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                                : Text(l10n.buttonUpdateCategory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
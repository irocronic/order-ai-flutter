// lib/screens/account_settings_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import '../services/firebase_storage_service.dart';
import '../providers/language_provider.dart';

class AccountSettingsScreen extends StatefulWidget {
  final String token;

  const AccountSettingsScreen({Key? key, required this.token}) : super(key: key);

  @override
  _AccountSettingsScreenState createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  bool isLoading = true;
  bool isSubmitting = false;
  String errorMessage = '';
  String successMessage = '';
  String? _currentProfileImageUrl;
  bool _isUploadingPicture = false;
  final ImagePicker _picker = ImagePicker();

  // === HATA DÜZELTME 1: Eksik değişkenler geri eklendi ===
  XFile? _pickedImageXFile;
  Uint8List? _webImageBytes;

  @override
  void initState() {
    super.initState();
    _fetchAccountSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccountSettings() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      final data = await ApiService.fetchMyUser(widget.token);
      final l10n = AppLocalizations.of(context)!;

      if (mounted) {
        setState(() {
          _username = data['username'] ?? l10n.unknownUser;
          _emailController.text = data['email'] ?? '';
          _currentProfileImageUrl = data['profile_image_url'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          errorMessage = l10n.accountSettingsErrorFetching(e.toString());
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingPicture || !mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null || !mounted) return;

    setState(() {
      _isUploadingPicture = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      Uint8List? imageBytes;
      if (kIsWeb) {
        imageBytes = await image.readAsBytes();
      }

      String fileName = p.basename(image.path);
      String firebaseFileName =
          "profile_pictures/user_${UserSession.userId}/${DateTime.now().millisecondsSinceEpoch}_$fileName";
          
      // === HATA DÜZELTME: _pickedImageXFile ataması doğru yere taşındı ===
      if (!kIsWeb) {
          _pickedImageXFile = image;
      }

      final String? downloadUrl = await FirebaseStorageService.uploadImage(
        imageFile:
            _pickedImageXFile != null ? File(_pickedImageXFile!.path) : null,
        imageBytes: imageBytes,
        fileName: firebaseFileName,
        folderPath: 'profile_pictures',
      );

      if (downloadUrl == null) {
        throw Exception(l10n.photoUploadErrorFirebase);
      }

      await ApiService.updateMyUser(
          widget.token, {'profile_image_url': downloadUrl});

      UserSession.updateProfileImageUrl(downloadUrl);
      if (mounted) {
        setState(() {
          _currentProfileImageUrl = downloadUrl;
          successMessage = l10n.accountSettingsSuccessPhotoUpdate;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(successMessage), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = l10n.accountSettingsErrorUploadingPhotoGeneric(e.toString().replaceFirst("Exception: ", "")));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPicture = false);
      }
    }
  }

  Future<void> _saveAccountSettings() async {
    if (!_formKey.currentState!.validate() || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;

    bool passwordFieldsFilled = _oldPasswordController.text.isNotEmpty ||
        _newPasswordController.text.isNotEmpty ||
        _confirmNewPasswordController.text.isNotEmpty;

    setState(() {
      isSubmitting = true;
      errorMessage = '';
      successMessage = '';
    });

    Map<String, dynamic> payload = {};
    payload['email'] = _emailController.text.trim();

    if (passwordFieldsFilled) {
      payload['old_password'] = _oldPasswordController.text;
      payload['new_password'] = _newPasswordController.text;
      payload['confirm_new_password'] = _confirmNewPasswordController.text;

      if (_newPasswordController.text != _confirmNewPasswordController.text) {
        if (mounted) {
          setState(() {
            errorMessage = l10n.accountSettingsErrorNewPasswordsMismatch;
            isSubmitting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(errorMessage), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }
    }

    try {
      await ApiService.updateMyUser(widget.token, payload);

      if (mounted) {
        setState(() {
          successMessage = l10n.accountSettingsSuccessUpdate;
          errorMessage = '';
          isSubmitting = false;
        });

        if (passwordFieldsFilled) {
          _oldPasswordController.clear();
          _newPasswordController.clear();
          _confirmNewPasswordController.clear();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.accountSettingsSuccessPasswordUpdate)),
          );
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.accountSettingsSuccessEmailUpdate)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = l10n.accountSettingsErrorUpdate(e.toString());
          successMessage = '';
          isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // === GÜNCELLENMİŞ METOT: Tüm diller eklendi ===
  Widget _buildLanguageSelector(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    // Proje genelinde desteklenen tüm dilleri buraya ekleyin.
    final Map<String, String> supportedLanguages = {
      'tr': l10n.languageNameTr,
      'en': l10n.languageNameEn,
      'de': l10n.languageNameDe,
      'es': l10n.languageNameEs,
      'ar': l10n.languageNameAr,
      'it': l10n.languageNameIt,
      'zh': l10n.languageNameZh,
      'ru': l10n.languageNameRu,
      'fr': l10n.languageNameFr,
    };

    String? currentLanguageCode = languageProvider.currentLocale?.languageCode ?? 
                                  Localizations.localeOf(context).languageCode;
    
    if (!supportedLanguages.keys.contains(currentLanguageCode)) {
      currentLanguageCode = 'tr'; 
    }

    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: currentLanguageCode,
        decoration: InputDecoration(
          labelText: l10n.language,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.language),
        ),
        items: supportedLanguages.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: (String? newLanguageCode) {
          if (newLanguageCode != null) {
            languageProvider.setLocale(Locale(newLanguageCode));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountSettingsTitle,
            
                style:
                    const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF283593),
                Color(0xFF455A64),
              ],
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
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: Colors.white.withOpacity(0.8),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.grey.shade300,
                                      backgroundImage: _currentProfileImageUrl !=
                                              null &&
                                              _currentProfileImageUrl!
                                                  .isNotEmpty
                                          ? NetworkImage(
                                              _currentProfileImageUrl!)
                                          : null,
                                      child: _isUploadingPicture
                                          ? const CircularProgressIndicator(
                                              color: Colors.white)
                                          : (_currentProfileImageUrl == null ||
                                                  _currentProfileImageUrl!
                                                      .isEmpty)
                                              ? const Icon(Icons.person,
                                                  size: 60,
                                                  color: Colors.white)
                                              : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Material(
                                        color: Colors.blueAccent,
                                        shape: const CircleBorder(),
                                        clipBehavior: Clip.hardEdge,
                                        child: InkWell(
                                          onTap: _isUploadingPicture
                                              ? null
                                              : _pickAndUploadImage,
                                          child: const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Icon(Icons.edit,
                                                color: Colors.white, size: 24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                initialValue: _username,
                                readOnly: true,
                                style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: l10n.usernameLabel,
                                  labelStyle:
                                      const TextStyle(color: Colors.black54),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: l10n.accountSettingsEmailLabel,
                                  labelStyle:
                                      const TextStyle(color: Colors.black87),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.emailHintRequired;
                                  }
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(value)) {
                                    return l10n.emailHintInvalid;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              _buildLanguageSelector(context),
                              
                              const SizedBox(height: 16),
                              Text(
                                l10n.accountSettingsPasswordChangeSectionTitle,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _oldPasswordController,
                                decoration: InputDecoration(
                                  labelText:
                                      l10n.accountSettingsCurrentPasswordLabel,
                                  labelStyle:
                                      const TextStyle(color: Colors.black87),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (_newPasswordController
                                          .text.isNotEmpty &&
                                      (value == null || value.isEmpty)) {
                                    return l10n.accountSettingsValidatorEnterCurrentPassword;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _newPasswordController,
                                decoration: InputDecoration(
                                  labelText:
                                      l10n.accountSettingsNewPasswordLabel,
                                  labelStyle:
                                      const TextStyle(color: Colors.black87),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (_oldPasswordController
                                          .text.isNotEmpty &&
                                      (value == null || value.isEmpty)) {
                                    return l10n.accountSettingsValidatorEnterNewPassword;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmNewPasswordController,
                                decoration: InputDecoration(
                                  labelText: l10n.accountSettingsConfirmNewPasswordLabel,
                                  labelStyle: const TextStyle(color: Colors.black87),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.7),
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (_newPasswordController.text.isNotEmpty) {
                                    if (value == null || value.isEmpty) {
                                      return l10n.accountSettingsValidatorConfirmNewPassword;
                                    }
                                    if (value != _newPasswordController.text) {
                                      return l10n.accountSettingsErrorPasswordsMismatch;
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: isSubmitting ? null : _saveAccountSettings,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  elevation: 5,
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white))
                                    : Text(l10n.accountSettingsSaveChangesButton,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
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
    );
  }
}
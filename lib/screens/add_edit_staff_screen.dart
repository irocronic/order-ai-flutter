// lib/screens/add_edit_staff_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../services/api_service.dart';
import '../models/staff_permission_keys.dart';
import '../models/notification_event_types.dart';
import '../models/kds_screen_model.dart';
import '../services/kds_management_service.dart';
import '../services/user_session.dart';
import '../models/permission_preset.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// YENİ: Vardiya yönetimi ekranını import ediyoruz
import 'schedule_management_screen.dart';

class AddEditStaffScreen extends StatefulWidget {
  final String token;
  final int businessId;
  final dynamic staff;
  final String staffUserType;

  const AddEditStaffScreen({
    Key? key,
    required this.token,
    required this.businessId,
    this.staff,
    this.staffUserType = 'staff',
  }) : super(key: key);

  @override
  _AddEditStaffScreenState createState() => _AddEditStaffScreenState();
}

class _AddEditStaffScreenState extends State<AddEditStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  bool _isEditMode = false;
  bool _isSubmitting = false;
  String _messageKey = '';
  String _errorMessageParam = '';
  bool _isActive = true;
  late String _currentUserType;
  
  // --- YENİ DEĞİŞKENLER ---
  List<String> _roleSpecificPagePermissions = [];
  List<String> _otherPagePermissions = [];
  List<String> _roleSpecificNotificationPermissions = [];
  List<String> _otherNotificationPermissions = [];
  // --- /YENİ DEĞİŞKENLER ---

  Map<String, bool> _pagePermissionsCheckboxes = {};
  Map<String, bool> _notificationPermissionsCheckboxes = {};

  List<KdsScreenModel> _availableKdsScreens = [];
  List<int> _selectedKdsScreenIds = [];
  bool _isLoadingKdsScreens = true;

  PermissionPreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.staff != null;
    _currentUserType = _isEditMode
        ? (widget.staff!['user_type'] ?? widget.staffUserType)
        : widget.staffUserType;

    _usernameController =
        TextEditingController(text: _isEditMode ? widget.staff!['username'] : '');
    _emailController =
        TextEditingController(text: _isEditMode ? widget.staff!['email'] : '');
    _passwordController = TextEditingController();
    _firstNameController =
        TextEditingController(text: _isEditMode ? widget.staff!['first_name'] : '');
    _lastNameController =
        TextEditingController(text: _isEditMode ? widget.staff!['last_name'] : '');
    _isActive = _isEditMode ? (widget.staff!['is_active'] ?? true) : true;

    _initializePermissions();
    if (_currentUserType == 'staff' || _currentUserType == 'kitchen_staff') {
      _fetchAvailableKdsScreens();
    } else {
      if (mounted) {
        setState(() => _isLoadingKdsScreens = false);
      }
    }
  }

  // ==================== YENİ FONKSİYON ====================
  void _initializePermissions() {
    // Önce tüm listeleri ve map'leri temizle
    _pagePermissionsCheckboxes = {};
    _notificationPermissionsCheckboxes = {};
    _roleSpecificPagePermissions = [];
    _otherPagePermissions = [];
    _roleSpecificNotificationPermissions = [];
    _otherNotificationPermissions = [];

    // 1. Role özgü anahtar listelerini belirle
    if (_currentUserType == 'staff') {
      _roleSpecificPagePermissions = PermissionKeys.DEFAULT_STAFF_PERMISSIONS;
      _roleSpecificNotificationPermissions = NotificationEventTypes.allEventKeys;
    } else if (_currentUserType == 'kitchen_staff') {
      _roleSpecificPagePermissions = PermissionKeys.DEFAULT_KITCHEN_PERMISSIONS;
      _roleSpecificNotificationPermissions = [
        NotificationEventTypes.orderApprovedForKitchen,
        NotificationEventTypes.orderPreparingUpdate,
        NotificationEventTypes.orderReadyForPickupUpdate,
        NotificationEventTypes.orderItemAdded,
        NotificationEventTypes.orderCancelledUpdate,
      ];
    }

    // 2. Diğer izinleri hesapla (tüm izinlerden role özgü olanları çıkar)
    _otherPagePermissions = PermissionKeys.allKeys
        .where((key) => !_roleSpecificPagePermissions.contains(key))
        .toList();
    _otherNotificationPermissions = NotificationEventTypes.allEventKeys
        .where((key) => !_roleSpecificNotificationPermissions.contains(key))
        .toList();

    // 3. Checkbox map'lerini TÜM izinlerle doldur
    for (final key in PermissionKeys.allKeys) {
      _pagePermissionsCheckboxes[key] = false;
    }
    for (final key in NotificationEventTypes.allEventKeys) {
      _notificationPermissionsCheckboxes[key] = false;
    }

    // 4. Düzenleme modundaysa, backend'den gelen seçili izinleri işaretle
    if (_isEditMode && widget.staff!['staff_permissions'] != null) {
      List<dynamic> staffPerms = widget.staff!['staff_permissions'];
      for (String permKey in staffPerms) {
        if (_pagePermissionsCheckboxes.containsKey(permKey)) {
          _pagePermissionsCheckboxes[permKey] = true;
        }
      }
    }
    if (_isEditMode && widget.staff!['notification_permissions'] != null) {
      List<dynamic> staffNotificationPerms =
          widget.staff!['notification_permissions'];
      for (String permKey in staffNotificationPerms) {
        if (_notificationPermissionsCheckboxes.containsKey(permKey)) {
          _notificationPermissionsCheckboxes[permKey] = true;
        }
      }
    }
  }

  Future<void> _fetchAvailableKdsScreens() async {
    if (!mounted) return;
    setState(() => _isLoadingKdsScreens = true);
    try {
      final List<KdsScreenModel> kdsModels =
          await KdsManagementService.fetchKdsScreens(widget.token, widget.businessId);
      if (mounted) {
        setState(() {
          _availableKdsScreens = kdsModels
              .where((kds) => kds.isActive)
              .toList();
          
          if (_isEditMode && widget.staff != null) {
            if (widget.staff!['accessible_kds_screens_details'] is List) {
              List<dynamic> currentKdsAccessDetails = widget.staff!['accessible_kds_screens_details'];
              _selectedKdsScreenIds = currentKdsAccessDetails
                  .map((kdsDetail) => kdsDetail['id'] as int)
                  .where((id) => _availableKdsScreens.any((kds) => kds.id == id))
                  .toList();
            } else {
              _selectedKdsScreenIds = [];
            }
          } else {
            _selectedKdsScreenIds = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint("Personele atanacak KDS ekranları çekilirken hata: $e");
        setState(() {
          _messageKey = "kdsLoadingError";
          _errorMessageParam = e.toString().replaceFirst("Exception: ", "");
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingKdsScreens = false);
    }
  }

  void _applyPermissionPreset(PermissionPreset? preset) {
    if (preset == null) return;
    setState(() {
      _selectedPreset = preset;
      _pagePermissionsCheckboxes.updateAll((key, value) => false);
      _notificationPermissionsCheckboxes.updateAll((key, value) => false);
      
      for (String key in preset.screenPermissions) {
        if (_pagePermissionsCheckboxes.containsKey(key)) {
          _pagePermissionsCheckboxes[key] = true;
        }
      }

      for (String key in preset.notificationPermissions) {
        if (_notificationPermissionsCheckboxes.containsKey(key)) {
          _notificationPermissionsCheckboxes[key] = true;
        }
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _messageKey = '';
      _errorMessageParam = '';
    });

    List<String> selectedPagePermissions = [];
    _pagePermissionsCheckboxes.forEach((key, value) {
      if (value == true) selectedPagePermissions.add(key);
    });

    List<String> selectedNotificationPermissions = [];
    _notificationPermissionsCheckboxes.forEach((key, value) {
      if (value == true) selectedNotificationPermissions.add(key);
    });

    Map<String, dynamic> staffData = {
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'is_active': _isActive,
      'staff_permissions': selectedPagePermissions,
      'notification_permissions': selectedNotificationPermissions,
      'user_type': _currentUserType,
      'accessible_kds_screen_ids': _selectedKdsScreenIds,
    };

    if (_passwordController.text.isNotEmpty || !_isEditMode) {
      staffData['password'] = _passwordController.text;
    }

    try {
      if (_isEditMode) {
        await ApiService.updateStaff(widget.token, widget.staff!['id'], staffData);
        _messageKey = 'staffUpdateSuccess';
      } else {
        await ApiService.createStaff(widget.token, staffData);
        _messageKey = 'staffCreateSuccess';
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_messageKey == 'staffUpdateSuccess' ? l10n.staffUpdateSuccess : l10n.staffCreateSuccess),  
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorKey = 'errorUsernameExists';
        String exceptionString = e.toString().toLowerCase();
        if (exceptionString.contains("user with this username already exists")) {
          errorKey = 'errorUsernameExists';
        } else if (exceptionString.contains("user with this email already exists")) {
          errorKey = 'errorEmailExists';
        }
        setState(() {
          _messageKey = errorKey;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
  
  String _getErrorMessageFromKey(AppLocalizations l10n, String key, String param) {
    if (key.isEmpty) return '';
    switch (key) {
        case 'errorUsernameExists': return l10n.errorUsernameExists;
        case 'errorEmailExists': return l10n.errorEmailExists;
        case 'kdsLoadingError': return l10n.kdsLoadingError(param);
        default: return l10n.unknownErrorOccurred;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String titleText;
    if (_isEditMode) {
      titleText = _currentUserType == 'kitchen_staff' ? l10n.editKitchenStaffTitle : l10n.editStaffTitle;
    } else {
      titleText = _currentUserType == 'kitchen_staff' ? l10n.addKitchenStaffTitle : l10n.addStaffTitle;
    }

    final errorMessageText = _getErrorMessageFromKey(l10n, _messageKey, _errorMessageParam);
    
    final localizedStaffPermissionNames = getStaffPermissionDisplayNames(l10n);
    final relevantNotificationDisplayNames = NotificationEventTypes.getDisplayNames(l10n);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900.withOpacity(0.9), Colors.blue.shade400.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.white.withOpacity(0.85),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${l10n.positionLabel}: ${_currentUserType == 'kitchen_staff' ? l10n.positionKitchenStaff : l10n.positionSalonStaff}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      flex: 0,
                      child: DropdownButtonFormField<String>(
                        value: _currentUserType,
                        decoration: InputDecoration(labelText: l10n.roleLabel),
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(value: 'staff', child: Text(l10n.roleStaff)),
                          DropdownMenuItem(value: 'kitchen_staff', child: Text(l10n.roleKitchenStaff)),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _currentUserType = newValue;
                              _initializePermissions();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(labelText: '${l10n.usernameLabel}*'),
                      validator: (value) => value == null || value.trim().isEmpty ? l10n.usernameHintRequired : (value.trim().length < 3 ? l10n.usernameHintMinLength.replaceFirst('4', '3') : null),
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: '${l10n.emailLabel}*'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return l10n.emailHintRequired;
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) return l10n.emailHintInvalid;
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(labelText: l10n.firstNameLabel),
                      validator: (value) => value == null || value.trim().isEmpty ? l10n.firstNameRequired : null,
                    ),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(labelText: l10n.lastNameLabel),
                      validator: (value) => value == null || value.trim().isEmpty ? l10n.lastNameRequired : null,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: _isEditMode ? l10n.passwordNewLabel : l10n.passwordRequiredLabel),
                      obscureText: true,
                      validator: (value) {
                        if (!_isEditMode && (value == null || value.isEmpty)) return l10n.passwordRequiredHintForNewStaff;
                        if (value != null && value.isNotEmpty && value.length < 6) return l10n.passwordHintMinLength;
                        return null;
                      },
                    ),
                    SwitchListTile(
                      title: Text(l10n.activeUserLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      value: _isActive,
                      onChanged: (bool value) => setState(() => _isActive = value),
                      activeColor: Colors.blueAccent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      flex: 0,
                      child: DropdownButtonFormField<PermissionPreset>(
                        value: _selectedPreset,
                        hint: Text(l10n.permissionPresetLabel),
                        isExpanded: true,
                        items: StaffPresets.all.map((preset) {
                          return DropdownMenuItem<PermissionPreset>(value: preset, child: Text(preset.title));
                        }).toList(),
                        onChanged: _applyPermissionPreset,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- EKRAN İZİNLERİ ---
                    Text(l10n.screenPermissionsLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(),

                    // Role özgü izinler her zaman görünür
                    ..._roleSpecificPagePermissions.map((key) {
                      return CheckboxListTile(
                        title: Text(localizedStaffPermissionNames[key] ?? key, style: const TextStyle(fontSize: 14)),
                        value: _pagePermissionsCheckboxes[key],
                        onChanged: (bool? newValue) => setState(() {
                          _pagePermissionsCheckboxes[key] = newValue ?? false;
                          _selectedPreset = null;
                        }),
                        activeColor: Colors.blueAccent,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      );
                    }).toList(),
                    
                    // Diğer izinler için açılır/kapanır alan
                    if (_otherPagePermissions.isNotEmpty)
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(l10n.setupStaffShowOtherPermissions, style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade700)),
                        children: _otherPagePermissions.map((key) {
                          return CheckboxListTile(
                            title: Text(localizedStaffPermissionNames[key] ?? key, style: const TextStyle(fontSize: 14)),
                            value: _pagePermissionsCheckboxes[key],
                            onChanged: (bool? newValue) => setState(() {
                              _pagePermissionsCheckboxes[key] = newValue ?? false;
                              _selectedPreset = null;
                            }),
                            activeColor: Colors.blueAccent,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16), // İçerinden başlasın
                          );
                        }).toList(),
                      ),
                    
                    const SizedBox(height: 20),

                    if (_currentUserType == 'staff' || _currentUserType == 'kitchen_staff') ...[
                      Text(l10n.accessibleKdsScreensLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (_isLoadingKdsScreens) const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      else if (_availableKdsScreens.isEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text(l10n.noKdsAvailable, style: const TextStyle(fontStyle: FontStyle.italic)))
                      else ..._availableKdsScreens.map((kdsScreen) {
                        return CheckboxListTile(
                          title: Text(kdsScreen.name, style: const TextStyle(fontSize: 14)),
                          subtitle: kdsScreen.description != null && kdsScreen.description!.isNotEmpty
                              ? Text(kdsScreen.description!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                              : null,
                          value: _selectedKdsScreenIds.contains(kdsScreen.id),
                          onChanged: (bool? selected) => setState(() {
                            if (selected == true) {
                              if (!_selectedKdsScreenIds.contains(kdsScreen.id)) _selectedKdsScreenIds.add(kdsScreen.id);
                            } else {
                              _selectedKdsScreenIds.remove(kdsScreen.id);
                            }
                          }),
                          activeColor: Colors.teal,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                    ],

                    // --- BİLDİRİM İZİNLERİ ---
                    Text(l10n.notificationPermissionsLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(),

                    // Role özgü bildirimler
                    ..._roleSpecificNotificationPermissions.map((key) {
                      return CheckboxListTile(
                        title: Text(relevantNotificationDisplayNames[key] ?? key, style: const TextStyle(fontSize: 13)),
                        value: _notificationPermissionsCheckboxes[key],
                        onChanged: (bool? newValue) => setState(() {
                          _notificationPermissionsCheckboxes[key] = newValue ?? false;
                          _selectedPreset = null;
                        }),
                        activeColor: Colors.deepPurpleAccent,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      );
                    }).toList(),

                    // Diğer bildirimler için açılır/kapanır alan
                    if (_otherNotificationPermissions.isNotEmpty)
                      ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(l10n.setupStaffShowOtherNotifications, style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade700)),
                        children: _otherNotificationPermissions.map((key) {
                          return CheckboxListTile(
                            title: Text(relevantNotificationDisplayNames[key] ?? key, style: const TextStyle(fontSize: 13)),
                            value: _notificationPermissionsCheckboxes[key],
                            onChanged: (bool? newValue) => setState(() {
                              _notificationPermissionsCheckboxes[key] = newValue ?? false;
                              _selectedPreset = null;
                            }),
                            activeColor: Colors.deepPurpleAccent,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          );
                        }).toList(),
                      ),
                    
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEditMode ? l10n.updateButton : l10n.createButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                    ),
                    if (errorMessageText.isNotEmpty && !_isSubmitting)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          errorMessageText,
                          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
// lib/widgets/setup_wizard/step_staff_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/setup_wizard_audio_service.dart'; // 🎵 YENİ EKLENEN
import '../../models/staff_permission_keys.dart';
import '../../services/user_session.dart';
import '../../screens/subscription_screen.dart';
import '../../models/kds_screen_model.dart';
import '../../services/kds_management_service.dart';
import '../../screens/schedule_management_screen.dart';
import '../../services/schedule_service.dart';

class StepStaffWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepStaffWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  StepStaffWidgetState createState() => StepStaffWidgetState();
}

class StepStaffWidgetState extends State<StepStaffWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _addedStaff = [];
  List<KdsScreenModel> _availableKdsScreens = [];
  late final AppLocalizations l10n;
  bool _didFetchData = false;
  final Map<int, bool> _staffShiftAssignmentStatus = {};

  // 🎵 YENİ EKLENEN: Audio servis referansı
  final SetupWizardAudioService _audioService = SetupWizardAudioService.instance;

  bool areAllStaffShiftsAssigned() {
    if (_addedStaff.isEmpty) return true;
    return _addedStaff.every((staff) => _staffShiftAssignmentStatus[staff['id']] == true);
  }

  int get createdStaffCount => _addedStaff.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      l10n = AppLocalizations.of(context)!;
      _fetchInitialData();
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
        _audioService.playStaffStepAudio(context: context);
      }
    });
  }

  @override
  void dispose() {
    // Sesli rehberliği durdur
    _audioService.stopAudio();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getStaffList(widget.token),
        KdsManagementService.fetchKdsScreens(widget.token, widget.businessId),
      ]);
      if (mounted) {
        setState(() {
          _addedStaff = results[0] as List<dynamic>;
          _availableKdsScreens = (results[1] as List<KdsScreenModel>).where((kds) => kds.isActive).toList();
        });
        await _checkAllStaffShiftStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = l10n.errorLoadingData(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAllStaffShiftStatus() async {
    for (var staff in _addedStaff) {
      final staffId = staff['id'] as int;
      final hasShifts = await ScheduleService.hasScheduledShifts(widget.token, staffId);
      if (mounted) {
        setState(() {
          _staffShiftAssignmentStatus[staffId] = hasShifts;
        });
      }
    }
  }

  Future<void> _navigateToShiftAssignment(dynamic newStaff) async {
    if (!mounted) return;
    final staffId = newStaff['id'] as int;
    final staffName = "${newStaff['first_name'] ?? ''} ${newStaff['last_name'] ?? ''}".trim().isNotEmpty
        ? "${newStaff['first_name']} ${newStaff['last_name']}"
        : newStaff['username'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.setupStaffRedirectingToSchedule(staffName)), duration: const Duration(seconds: 2)),
    );
    await Future.delayed(const Duration(seconds: 1));
    final bool? shiftAssigned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleManagementScreen(
          token: widget.token,
          businessId: widget.businessId,
          isFromSetupWizard: true,
          preSelectedStaffId: staffId,
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _staffShiftAssignmentStatus[staffId] = shiftAssigned ?? false;
      });
      await _fetchInitialData();
    }
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

  Future<void> _showAddStaffDialog() async {
    if (_addedStaff.length >= UserSession.limitsNotifier.value.maxStaff) {
      _showLimitReachedDialog(l10n.manageStaffErrorLimitExceeded(UserSession.limitsNotifier.value.maxStaff.toString()));
      return;
    }

    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    // ==================== YENİ KOD (1/3): E-posta için Controller ====================
    final emailController = TextEditingController();
    // =============================================================================

    String selectedRole = 'staff';
    final Set<int> _selectedKdsScreenIds = {};
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final dialogL10n = AppLocalizations.of(context)!;
          final inputDecorationTheme = InputDecoration(
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
            errorStyle: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white, width: 1.5),
            ),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
            ),
          );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A237E).withOpacity(0.98),
                      const Color(0xFF303F9F).withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.setupStaffDialogTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: inputDecorationTheme.copyWith(labelText: l10n.usernameLabel),
                            validator: (value) => (value == null || value.trim().isEmpty) ? l10n.usernameHintRequired : null,
                          ),
                          const SizedBox(height: 16),
                          
                          // ==================== YENİ KOD (2/3): E-posta TextFormField ====================
                          TextFormField(
                            controller: emailController,
                            style: const TextStyle(color: Colors.white),
                            decoration: inputDecorationTheme.copyWith(labelText: l10n.emailLabel),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.emailHintRequired;
                              }
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                                return l10n.emailHintInvalid;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // ============================================================================

                          TextFormField(
                            controller: passwordController,
                            style: const TextStyle(color: Colors.white),
                            decoration: inputDecorationTheme.copyWith(labelText: l10n.passwordLabel),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) return l10n.passwordHintRequired;
                              if (value.length < 6) return l10n.passwordHintMinLength;
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: firstNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: inputDecorationTheme.copyWith(labelText: l10n.firstNameLabel),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: lastNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: inputDecorationTheme.copyWith(labelText: l10n.lastNameLabel),
                          ),
                          const SizedBox(height: 24),
                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            isExpanded: true,
                            dropdownColor: Colors.blue.shade800,
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            decoration: inputDecorationTheme.copyWith(
                              labelText: l10n.roleLabel,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.white, width: 1.5),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(value: 'staff', child: Text(l10n.roleStaff)),
                              DropdownMenuItem(value: 'kitchen_staff', child: Text(l10n.roleKitchenStaff)),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedRole = value;
                                  if (selectedRole == 'kitchen_staff' && _availableKdsScreens.length == 1) {
                                    _selectedKdsScreenIds.clear();
                                    _selectedKdsScreenIds.add(_availableKdsScreens.first.id);
                                  } else {
                                    _selectedKdsScreenIds.clear();
                                  }
                                });
                              }
                            },
                          ),
                          if (selectedRole == 'kitchen_staff') ...[
                            const SizedBox(height: 24),
                            Text(l10n.kdsAccessSelectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            const Divider(color: Colors.white38),
                            if (_availableKdsScreens.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(l10n.kdsAccessNoKdsAvailable, style: TextStyle(color: Colors.orange.shade300)),
                              )
                            else
                              ..._availableKdsScreens.map((kds) {
                                return Theme(
                                  data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white70),
                                  child: CheckboxListTile(
                                    title: Text(kds.name, style: const TextStyle(color: Colors.white)),
                                    value: _selectedKdsScreenIds.contains(kds.id),
                                    activeColor: Colors.lightBlueAccent,
                                    checkColor: Colors.indigo.shade900,
                                    onChanged: (bool? value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          _selectedKdsScreenIds.add(kds.id);
                                        } else {
                                          _selectedKdsScreenIds.remove(kds.id);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                          ],
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                                style: TextButton.styleFrom(foregroundColor: Colors.white.withOpacity(0.8)),
                                child: Text(l10n.dialogButtonCancel),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: isSubmitting ? null : () async {
                                  if (formKey.currentState!.validate()) {
                                    setDialogState(() => isSubmitting = true);
                                    
                                    List<String> permissions = [];
                                    List<String> notificationPermissions = [];
                                    
                                    if(selectedRole == 'staff') {
                                        permissions = PermissionKeys.DEFAULT_STAFF_PERMISSIONS;
                                        notificationPermissions = PermissionKeys.DEFAULT_STAFF_NOTIFICATION_PERMISSIONS; 
                                    } else { 
                                        permissions = PermissionKeys.DEFAULT_KITCHEN_PERMISSIONS;
                                        notificationPermissions = PermissionKeys.DEFAULT_KITCHEN_NOTIFICATION_PERMISSIONS;
                                    }

                                    // ==================== YENİ KOD (3/3): Payload'a email ekleniyor ====================
                                    final staffData = {
                                      'username': usernameController.text.trim(),
                                      'email': emailController.text.trim(), // EKLENDİ
                                      'password': passwordController.text.trim(),
                                      'first_name': firstNameController.text.trim(),
                                      'last_name': lastNameController.text.trim(),
                                      'user_type': selectedRole,
                                      'staff_permissions': permissions,
                                      'notification_permissions': notificationPermissions,
                                      'accessible_kds_screen_ids': _selectedKdsScreenIds.toList(),
                                    };
                                    // ===============================================================================

                                    try {
                                      final newStaff = await ApiService.createStaff(widget.token, staffData);
                                      if (mounted) {
                                        Navigator.of(dialogContext).pop();
                                        await _navigateToShiftAssignment(newStaff);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        String rawError = e.toString().replaceFirst("Exception: ", "");
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(rawError), backgroundColor: Colors.redAccent));
                                      }
                                    } finally {
                                      if(mounted) {
                                        setDialogState(() => isSubmitting = false);
                                      }
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                child: isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l10n.buttonAdd),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
    usernameController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose(); // Controller'ı dispose et
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
                  _audioService.playStaffStepAudio(context: context);
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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

          Text(
            l10n.setupStaffDescription,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.addStaffButtonLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.2),
              side: const BorderSide(color: Colors.white),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: _showAddStaffDialog,
          ),
          const SizedBox(height: 24),
          Text(l10n.setupStaffAddedTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Divider(color: Colors.white70),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMessage, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          _addedStaff.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(l10n.noStaffAdded, style: const TextStyle(color: Colors.white70))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _addedStaff.length,
                  itemBuilder: (context, index) {
                    final staff = _addedStaff[index];
                    final bool hasShiftAssigned = _staffShiftAssignmentStatus[staff['id']] ?? false;
                    return Card(
                      color: Colors.white.withOpacity(0.8),
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text("${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}".trim()),
                        subtitle: Text(staff['username'] ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasShiftAssigned)
                              Tooltip(
                                message: l10n.setupStaffShiftAssigned,
                                child: Icon(Icons.check_circle, color: Colors.green.shade600),
                              )
                            else
                              Tooltip(
                                message: l10n.setupStaffShiftNotAssigned,
                                child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                              ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.calendar_month_outlined, size: 18),
                              label: Text(l10n.setupStaffAssignShiftButton),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.deepPurple.shade300,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () => _navigateToShiftAssignment(staff),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 10),
          Text(
            l10n.setupStaffTotalCreatedWithLimit(_addedStaff.length.toString(), UserSession.limitsNotifier.value.maxStaff.toString()),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
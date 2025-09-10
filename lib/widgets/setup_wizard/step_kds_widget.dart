// lib/widgets/setup_wizard/step_kds_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/kds_service.dart';
import '../../services/setup_wizard_audio_service.dart'; // 🎵 YENİ EKLENEN
import '../../models/kds_screen_model.dart';
import '../../services/user_session.dart';
import '../../screens/subscription_screen.dart';

class StepKdsWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepKdsWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  StepKdsWidgetState createState() => StepKdsWidgetState();
}

class StepKdsWidgetState extends State<StepKdsWidget> {
  final _formKey = GlobalKey<FormState>();
  int _kdsCount = 1;
  List<TextEditingController> _nameControllers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _errorMessage = '';
  String _successMessage = '';
  List<KdsScreenModel> createdKdsScreens = [];
  late final AppLocalizations l10n;
  bool _didFetchData = false;

  // 🎵 YENİ EKLENEN: Audio servis referansı
  final SetupWizardAudioService _audioService = SetupWizardAudioService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      l10n = AppLocalizations.of(context)!;
      _fetchExistingKdsScreens();
      _updateNameControllers(1);
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
        _audioService.playKdsStepAudio(context: context);
      }
    });
  }

  @override
  void dispose() {
    // Sesli rehberliği durdur
    _audioService.stopAudio();
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchExistingKdsScreens() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final screens =
          await KdsService.fetchKdsScreens(widget.token, widget.businessId);
      if (mounted) {
        setState(() {
          createdKdsScreens = screens;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.setupKdsErrorLoadingExisting(
              e.toString().replaceFirst("Exception: ", ""));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateNameControllers(int count) {
    if (!mounted) return;
    setState(() {
      for (var controller in _nameControllers) {
        controller.dispose();
      }
      _nameControllers = List.generate(count, (index) {
        if (count == 1 && index == 0) {
          return TextEditingController(text: l10n.setupKdsDefaultKitchen);
        } else if (count == 2 && index == 0) {
          return TextEditingController(text: l10n.setupKdsDefaultKitchen);
        } else if (count == 2 && index == 1) {
          return TextEditingController(text: l10n.setupKdsDefaultBar);
        }
        return TextEditingController();
      });
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
  
  Future<void> _createKdsScreens() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    
    final List<String> names = _nameControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      setState(() {
        _errorMessage = l10n.setupKdsErrorEnterOneName;
      });
      return;
    }
    
    // *** DEĞİŞİKLİK BURADA: Artık `UserSession.limitsNotifier`'dan gelen anlık veriyi kullanıyoruz. ***
    final currentLimits = UserSession.limitsNotifier.value;
    if (createdKdsScreens.length + names.length > currentLimits.maxKdsScreens) {
      _showLimitReachedDialog(
        l10n.setupKdsErrorLimitExceeded(
          currentLimits.maxKdsScreens.toString(),
          createdKdsScreens.length.toString(),
          names.length.toString(),
        )
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final createdScreens = await KdsService.bulkCreateKdsScreens(
          widget.token, widget.businessId, names);
      if (mounted) {
        setState(() {
          _successMessage = l10n.setupKdsSuccessCreated(createdScreens.length);
          _kdsCount = 1;
        });
        _updateNameControllers(1);
        await _fetchExistingKdsScreens();
        _clearMessagesAfterDelay();
      }
    } catch (e) {
      if (mounted) {
        String rawError = e.toString().replaceFirst("Exception: ", "");
        final jsonStartIndex = rawError.indexOf('{');
        if (jsonStartIndex != -1) {
          try {
            final jsonString = rawError.substring(jsonStartIndex);
            final decodedError = jsonDecode(jsonString);
            if (decodedError is Map && decodedError['code'] == 'limit_reached') {
              _showLimitReachedDialog(decodedError['detail']);
              _errorMessage = ''; 
            } else {
              _errorMessage = decodedError['detail'] ?? rawError;
            }
          } catch (jsonError) {
            _errorMessage = rawError;
          }
        } else {
          _errorMessage = rawError;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteKdsScreen(KdsScreenModel kdsScreen) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.setupKdsDeleteDialogTitle),
        content: Text(l10n.setupKdsDeleteDialogContent(kdsScreen.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.dialogButtonCancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.dialogButtonDelete,
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await KdsService.deleteKdsScreen(widget.token, kdsScreen.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.setupKdsInfoDeleted(kdsScreen.name)),
            backgroundColor: Colors.orange));
      }
      await _fetchExistingKdsScreens();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            l10n.setupKdsErrorDeleting(e.toString().replaceFirst("Exception: ", "")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditKdsDialog(KdsScreenModel kdsScreen) async {
    final nameController = TextEditingController(text: kdsScreen.name);
    bool isActive = kdsScreen.isActive;

    final bool? wasUpdated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.setupKdsEditDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      InputDecoration(labelText: l10n.setupKdsEditDialogNameLabel),
                ),
                SwitchListTile(
                  title: Text(l10n.setupKdsEditDialogActiveLabel),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                )
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.dialogButtonCancel)),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await KdsService.updateKdsScreen(
                      widget.token,
                      kdsScreen.id,
                      widget.businessId,
                      nameController.text.trim(),
                      kdsScreen.description,
                      isActive,
                    );
                    if (mounted) Navigator.of(dialogContext).pop(true);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(l10n.setupKdsErrorUpdating(e.toString())),
                          backgroundColor: Colors.red));
                    }
                  }
                },
                child: Text(l10n.buttonSave),
              ),
            ],
          );
        });
      },
    );

    if (wasUpdated == true) {
      _fetchExistingKdsScreens();
    }
  }

  void _clearMessagesAfterDelay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && (_successMessage.isNotEmpty || _errorMessage.isNotEmpty)) {
        setState(() {
          _successMessage = '';
          _errorMessage = '';
        });
      }
    });
  }

  void _incrementQuantity() {
    if (_kdsCount < 10) {
      setState(() {
        _kdsCount++;
        _updateNameControllers(_kdsCount);
      });
    }
  }

  void _decrementQuantity() {
    if (_kdsCount > 1) {
      setState(() {
        _kdsCount--;
        _updateNameControllers(_kdsCount);
      });
    }
  }

  Widget _buildNumberPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.remove_circle_outline,
                color: Colors.red.shade400, size: 32),
            onPressed: _isSubmitting ? null : _decrementQuantity,
          ),
          Text(
            _kdsCount.toString(),
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline,
                color: Colors.green.shade600, size: 32),
            onPressed: _isSubmitting ? null : _incrementQuantity,
          ),
        ],
      ),
    );
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
                  _audioService.playKdsStepAudio(context: context);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
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
            l10n.setupKdsDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.white.withOpacity(0.85),
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text(l10n.setupKdsNewLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    _buildNumberPicker(),
                    const SizedBox(height: 12),
                    ..._nameControllers.map((controller) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                              labelText: l10n.setupKdsScreenNameLabel(
                                  _nameControllers.indexOf(controller) + 1)),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? l10n.setupKdsScreenNameValidator
                              : null,
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox.shrink()
                          : const Icon(Icons.add_circle_outline),
                      label: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(l10n.setupKdsAddButton),
                      onPressed: _isSubmitting ? null : _createKdsScreens,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(45),
                          textStyle: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.setupKdsExistingTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Divider(color: Colors.white70),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage.isNotEmpty && createdKdsScreens.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMessage, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            )
          else if (createdKdsScreens.isEmpty)
            Center(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(l10n.setupKdsNoScreensYet, style: const TextStyle(color: Colors.white70))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: createdKdsScreens.length,
              itemBuilder: (context, index) {
                final kds = createdKdsScreens[index];
                final statusText = kds.isActive
                    ? l10n.setupKdsStatusActive
                    : l10n.setupKdsStatusInactive;
                return Card(
                  color: Colors.white.withOpacity(0.8),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(kds.name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(l10n.setupKdsStatusLabel(statusText)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.blueAccent),
                          tooltip: l10n.tooltipEdit,
                          onPressed: () => _showEditKdsDialog(kds),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          tooltip: l10n.tooltipDelete,
                          onPressed: () => _deleteKdsScreen(kds),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_successMessage.isNotEmpty || _errorMessage.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                _successMessage.isNotEmpty ? _successMessage : _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _successMessage.isNotEmpty
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                    fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 10),
          if (!_isLoading)
            // === DEĞİŞİKLİK BURADA: Metin, ValueListenableBuilder ile sarmalandı ===
            ValueListenableBuilder<SubscriptionLimits>(
              valueListenable: UserSession.limitsNotifier,
              builder: (context, limits, child) {
                return Text(
                  l10n.setupKdsTotalCreatedWithLimit(createdKdsScreens.length.toString(), limits.maxKdsScreens.toString()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.8)),
                );
              },
            ),
        ],
      ),
    );
  }
}
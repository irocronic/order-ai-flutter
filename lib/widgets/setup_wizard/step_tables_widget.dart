// lib/widgets/setup_wizard/step_tables_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/user_session.dart';
import '../../services/setup_wizard_audio_service.dart'; // 🎵 YENİ EKLENEN
import '../../screens/subscription_screen.dart';

class StepTablesWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepTablesWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  StepTablesWidgetState createState() => StepTablesWidgetState();
}

class StepTablesWidgetState extends State<StepTablesWidget> {
  final _formKey = GlobalKey<FormState>();
  int _tableCount = 1;
  bool _isSubmitting = false;
  bool _isLoadingInitialData = true;
  String _errorMessage = '';
  String _successMessage = '';
  int createdTableCount = 0;
  late final AppLocalizations l10n;
  bool _didFetchData = false;

  // 🎵 YENİ EKLENEN: Audio servis referansı
  final SetupWizardAudioService _audioService = SetupWizardAudioService.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      l10n = AppLocalizations.of(context)!;
      _fetchCurrentTableCount();
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
        _audioService.playTablesStepAudio(context: context);
      }
    });
  }

  Future<void> _fetchCurrentTableCount() async {
    if (!mounted) return;
    setState(() => _isLoadingInitialData = true);
    try {
      final tablesData = await ApiService.fetchTablesForBusiness(widget.token);
      if (mounted) {
        setState(() {
          createdTableCount = tablesData.length;
        });
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = l10n.setupTablesErrorLoadingExisting;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitialData = false);
      }
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

  Future<void> _createTables() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    
    final currentLimits = UserSession.limitsNotifier.value;
    final int countToAdd = _tableCount;
    if (createdTableCount + countToAdd > currentLimits.maxTables) {
      _showLimitReachedDialog(
        l10n.setupTablesErrorLimitExceeded(
          currentLimits.maxTables.toString(),
          createdTableCount.toString(),
          countToAdd.toString(),
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
      final createdTables =
          await ApiService.bulkCreateTables(widget.token, widget.businessId, countToAdd);
      if (mounted) {
        setState(() {
          createdTableCount += createdTables.length;
          _successMessage = l10n.setupTablesSuccessCreated(
              createdTables.length.toString(), createdTableCount.toString());
          _tableCount = 1;
          FocusScope.of(context).unfocus();
        });
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
        _clearMessagesAfterDelay();
      }
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
    if (_tableCount < 100) {
      setState(() {
        _tableCount++;
      });
    }
  }

  void _decrementQuantity() {
    if (_tableCount > 1) {
      setState(() {
        _tableCount--;
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
            _tableCount.toString(),
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
                  _audioService.playTablesStepAudio(context: context);
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
  void dispose() {
    // Sesli rehberliği durdur
    _audioService.stopAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            l10n.setupTablesDescription,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.setupTablesLabelQuantity,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    _buildNumberPicker(),
                    const SizedBox(height: 24),
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
                          : Text(l10n.setupTablesButtonCreate),
                      onPressed: _isSubmitting ? null : _createTables,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoadingInitialData)
            Center(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(l10n.setupTablesLoadingExisting, style: const TextStyle(color: Colors.white70),)))
          else ...[
            if (_successMessage.isNotEmpty || _errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
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
            ValueListenableBuilder<SubscriptionLimits>(
              valueListenable: UserSession.limitsNotifier,
              builder: (context, limits, child) {
                return Text(
                  l10n.setupTablesTotalCreatedWithLimit(createdTableCount.toString(), limits.maxTables.toString()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9)),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
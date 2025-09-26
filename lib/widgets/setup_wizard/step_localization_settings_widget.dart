// lib/widgets/setup_wizard/step_localization_settings_widget.dart

import 'dart:async';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // debugPrint için eklendi

import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/user_session.dart';
import '../../services/setup_wizard_audio_service.dart';

class StepLocalizationSettingsWidget extends StatefulWidget {
  final String token;
  final int businessId;
  final VoidCallback onNext;

  const StepLocalizationSettingsWidget({
    Key? key,
    required this.token,
    required this.businessId,
    required this.onNext,
  }) : super(key: key);

  @override
  _StepLocalizationSettingsWidgetState createState() =>
      _StepLocalizationSettingsWidgetState();
}

class _StepLocalizationSettingsWidgetState
    extends State<StepLocalizationSettingsWidget> {
  String? _selectedLanguageCode;
  String? _selectedCurrency;
  String? _selectedTimezone;

  bool _isInitialized = false;

  final SetupWizardAudioService _audioService = SetupWizardAudioService.instance;

  late Map<String, String> _supportedLanguages;
  late Map<String, String> _supportedCurrencies;
  late Map<String, String> _supportedTimezones;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final l10n = AppLocalizations.of(context)!;

      _supportedLanguages = {
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

      _supportedCurrencies = {
        'TRY': l10n.currencyNameTRY,
        'USD': l10n.currencyNameUSD,
        'EUR': l10n.currencyNameEUR,
        'GBP': l10n.currencyNameGBP,
      };

      _supportedTimezones = {
        'Europe/Istanbul': l10n.timeZoneNameIstanbul,
        'Europe/London': l10n.timeZoneNameLondon,
        'Europe/Berlin': l10n.timeZoneNameBerlin,
        'America/New_York': l10n.timeZoneNameNewYork,
        'Asia/Dubai': l10n.timeZoneNameDubai,
        'Asia/Tokyo': l10n.timeZoneNameTokyo,
      };

      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      _selectedLanguageCode ??=
          languageProvider.currentLocale?.languageCode ?? 'tr';
      _selectedCurrency ??= UserSession.currencyCode ?? 'TRY';
      _selectedTimezone ??= 'Europe/Istanbul';
      _isInitialized = true;

      _startVoiceGuidance();
    }
  }

  void _startVoiceGuidance() {
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _audioService.playLocalizationStepAudio(context: context);
      }
    });
  }

  @override
  void dispose() {
    _audioService.stopAudio();
    super.dispose();
  }

  void _onLanguageChanged(String? newLanguageCode) async {
    if (newLanguageCode != null) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      await languageProvider.setLocale(Locale(newLanguageCode));

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _audioService.playLocalizationStepAudio(context: context);
        }
      });

      _saveSettings();
    }
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final Map<String, dynamic> payload = {};
      if (_selectedCurrency != null) {
        payload['currency_code'] = _selectedCurrency;
      }
      if (_selectedTimezone != null) {
        payload['timezone'] = _selectedTimezone;
      }

      if (payload.isNotEmpty) {
        await ApiService.updateBusinessSettings(
          widget.token,
          widget.businessId,
          payload,
        );
        if (_selectedCurrency != null) {
          UserSession.updateCurrencyCode(_selectedCurrency);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.setupWizardSettingsSaved),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.setupWizardErrorSavingSettings(e.toString())),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildAudioControlButton(AppLocalizations l10n) {
    return ValueListenableBuilder<bool>(
      valueListenable: ValueNotifier(_audioService.isMuted),
      builder: (context, isMuted, child) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_audioService.isPlaying)
                Flexible(
                  child: Container(
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
                        Flexible(
                          child: Text(
                            l10n.voiceGuideActive,
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                tooltip: isMuted ? l10n.tooltipUnmute : l10n.tooltipMute,
                style: IconButton.styleFrom(
                  backgroundColor: isMuted 
                    ? Colors.red.withOpacity(0.2) 
                    : Colors.blue.withOpacity(0.2),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.replay,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                onPressed: _audioService.isMuted ? null : () {
                  _audioService.playLocalizationStepAudio(context: context);
                },
                tooltip: l10n.tooltipReplayGuide,
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final l10n = AppLocalizations.of(context)!;

        _supportedLanguages = {
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

        _supportedCurrencies = {
          'TRY': l10n.currencyNameTRY,
          'USD': l10n.currencyNameUSD,
          'EUR': l10n.currencyNameEUR,
          'GBP': l10n.currencyNameGBP,
        };

        _supportedTimezones = {
          'Europe/Istanbul': l10n.timeZoneNameIstanbul,
          'Europe/London': l10n.timeZoneNameLondon,
          'Europe/Berlin': l10n.timeZoneNameBerlin,
          'America/New_York': l10n.timeZoneNameNewYork,
          'Asia/Dubai': l10n.timeZoneNameDubai,
          'Asia/Tokyo': l10n.timeZoneNameTokyo,
        };

        _selectedLanguageCode = languageProvider.currentLocale?.languageCode ??
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;

        const welcomeTextStyle = TextStyle(
          fontSize: 40.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        );

        final inputDecoration = InputDecoration(
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white54)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white)),
          border: const OutlineInputBorder(),
          prefixIconColor: Colors.white.withOpacity(0.7),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildAudioControlButton(l10n),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: AnimatedTextKit(
                  animatedTexts: [
                    FadeAnimatedText(l10n.welcomeMessageTr, textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                    FadeAnimatedText(l10n.welcomeMessageEn, textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                    FadeAnimatedText(l10n.welcomeMessageEs, textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                    FadeAnimatedText(l10n.welcomeMessageDe, textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                    FadeAnimatedText(l10n.welcomeMessageFr, textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                    FadeAnimatedText(l10n.welcomeMessageIt, textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                    FadeAnimatedText(l10n.welcomeMessageAr, textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                    FadeAnimatedText(l10n.welcomeMessageZh, textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                  ],
                  pause: const Duration(milliseconds: 1500),
                  repeatForever: true,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.white.withOpacity(0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedLanguageCode,
                        dropdownColor: Colors.blue.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration.copyWith(
                          labelText: l10n.language,
                          prefixIcon: Icon(Icons.language, color: Colors.white.withOpacity(0.7)),
                        ),
                        items: _supportedLanguages.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        selectedItemBuilder: (BuildContext context) {
                          return _supportedLanguages.values
                              .map<Widget>((String item) {
                            return Text(item, style: const TextStyle(color: Colors.white));
                          }).toList();
                        },
                        onChanged: _onLanguageChanged,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        dropdownColor: Colors.blue.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration.copyWith(
                          labelText: l10n.businessSettingsCurrencyLabel,
                          prefixIcon: Icon(Icons.monetization_on_outlined, color: Colors.white.withOpacity(0.7)),
                        ),
                        items: _supportedCurrencies.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        selectedItemBuilder: (BuildContext context) {
                          return _supportedCurrencies.values
                              .map<Widget>((String item) {
                            return Text(item, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis);
                          }).toList();
                        },
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedCurrency = newValue);
                            _saveSettings();
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedTimezone,
                        isExpanded: true,
                        dropdownColor: Colors.blue.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration.copyWith(
                          labelText: l10n.businessSettingsTimezoneLabel,
                          prefixIcon: Icon(Icons.access_time_outlined, color: Colors.white.withOpacity(0.7)),
                        ),
                        items: _supportedTimezones.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        selectedItemBuilder: (BuildContext context) {
                          return _supportedTimezones.values
                              .map<Widget>((String item) {
                            return Text(item, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis);
                          }).toList();
                        },
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedTimezone = newValue);
                            _saveSettings();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }
}
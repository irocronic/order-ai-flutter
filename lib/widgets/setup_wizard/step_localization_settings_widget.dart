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

// Dil bilgilerini tutmak için sınıf
class LanguageInfo {
  final String code;
  final String name;
  final String flag;

  LanguageInfo({required this.code, required this.name, required this.flag});
}

// Zaman dilimi kategorilerini tutmak için sınıf
class TimezoneCategory {
  final String name;
  final List<TimezoneInfo> timezones;

  TimezoneCategory({required this.name, required this.timezones});
}

class TimezoneInfo {
  final String code;
  final String name;

  TimezoneInfo({required this.code, required this.name});
}

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

  late List<LanguageInfo> _supportedLanguages;
  late Map<String, String> _supportedCurrencies;
  late List<TimezoneCategory> _timezoneCategories;

  @override
  void initState() {
    super.initState();
  }

  List<LanguageInfo> _getSupportedLanguages(AppLocalizations l10n) {
    return [
      LanguageInfo(code: 'tr', name: l10n.languageNameTr, flag: '🇹🇷'),
      LanguageInfo(code: 'en', name: l10n.languageNameEn, flag: '🇺🇸'),
      LanguageInfo(code: 'de', name: l10n.languageNameDe, flag: '🇩🇪'),
      LanguageInfo(code: 'es', name: l10n.languageNameEs, flag: '🇪🇸'),
      LanguageInfo(code: 'ar', name: l10n.languageNameAr, flag: '🇸🇦'),
      LanguageInfo(code: 'it', name: l10n.languageNameIt, flag: '🇮🇹'),
      LanguageInfo(code: 'zh', name: l10n.languageNameZh, flag: '🇨🇳'),
      LanguageInfo(code: 'ru', name: l10n.languageNameRu, flag: '🇷🇺'),
      LanguageInfo(code: 'fr', name: l10n.languageNameFr, flag: '🇫🇷'),
    ];
  }

  List<TimezoneCategory> _getTimezoneCategories(AppLocalizations l10n) {
    return [
      TimezoneCategory(
        name: l10n.continentEurope,
        timezones: [
          TimezoneInfo(code: 'Europe/Istanbul', name: l10n.timeZoneNameIstanbul),
          TimezoneInfo(code: 'Europe/London', name: l10n.timeZoneNameLondon),
          TimezoneInfo(code: 'Europe/Berlin', name: l10n.timeZoneNameBerlin),
          TimezoneInfo(code: 'Europe/Paris', name: l10n.timeZoneNameParis),
          TimezoneInfo(code: 'Europe/Rome', name: l10n.timeZoneNameRome),
          TimezoneInfo(code: 'Europe/Madrid', name: l10n.timeZoneNameMadrid),
          TimezoneInfo(code: 'Europe/Amsterdam', name: l10n.timeZoneNameAmsterdam),
          TimezoneInfo(code: 'Europe/Vienna', name: l10n.timeZoneNameVienna),
          TimezoneInfo(code: 'Europe/Warsaw', name: l10n.timeZoneNameWarsaw),
          TimezoneInfo(code: 'Europe/Prague', name: l10n.timeZoneNamePrague),
          TimezoneInfo(code: 'Europe/Budapest', name: l10n.timeZoneNameBudapest),
          TimezoneInfo(code: 'Europe/Athens', name: l10n.timeZoneNameAthens),
          TimezoneInfo(code: 'Europe/Helsinki', name: l10n.timeZoneNameHelsinki),
          TimezoneInfo(code: 'Europe/Stockholm', name: l10n.timeZoneNameStockholm),
          TimezoneInfo(code: 'Europe/Oslo', name: l10n.timeZoneNameOslo),
          TimezoneInfo(code: 'Europe/Copenhagen', name: l10n.timeZoneNameCopenhagen),
          TimezoneInfo(code: 'Europe/Brussels', name: l10n.timeZoneNameBrussels),
          TimezoneInfo(code: 'Europe/Zurich', name: l10n.timeZoneNameZurich),
          TimezoneInfo(code: 'Europe/Moscow', name: l10n.timeZoneNameMoscow),
        ],
      ),
      TimezoneCategory(
        name: l10n.continentAsia,
        timezones: [
          // Doğu Asya
          TimezoneInfo(code: 'Asia/Tokyo', name: l10n.timeZoneNameTokyo),
          TimezoneInfo(code: 'Asia/Seoul', name: l10n.timeZoneNameSeoul),
          TimezoneInfo(code: 'Asia/Shanghai', name: l10n.timeZoneNameShanghai),
          TimezoneInfo(code: 'Asia/Hong_Kong', name: l10n.timeZoneNameHongKong),
          TimezoneInfo(code: 'Asia/Singapore', name: l10n.timeZoneNameSingapore),
          TimezoneInfo(code: 'Asia/Bangkok', name: l10n.timeZoneNameBangkok),
          TimezoneInfo(code: 'Asia/Manila', name: l10n.timeZoneNameManila),
          TimezoneInfo(code: 'Asia/Jakarta', name: l10n.timeZoneNameJakarta),
          TimezoneInfo(code: 'Asia/Kuala_Lumpur', name: l10n.timeZoneNameKualaLumpur),
          TimezoneInfo(code: 'Asia/Ho_Chi_Minh', name: l10n.timeZoneNameHoChiMinh),
          
          // Orta & Batı Asya
          TimezoneInfo(code: 'Asia/Dubai', name: l10n.timeZoneNameDubai),
          TimezoneInfo(code: 'Asia/Riyadh', name: l10n.timeZoneNameRiyadh),
          TimezoneInfo(code: 'Asia/Qatar', name: l10n.timeZoneNameQatar),
          TimezoneInfo(code: 'Asia/Kuwait', name: l10n.timeZoneNameKuwait),
          TimezoneInfo(code: 'Asia/Tehran', name: l10n.timeZoneNameTehran),
          TimezoneInfo(code: 'Asia/Baghdad', name: l10n.timeZoneNameBaghdad),
          TimezoneInfo(code: 'Asia/Kabul', name: l10n.timeZoneNameKabul),
          TimezoneInfo(code: 'Asia/Karachi', name: l10n.timeZoneNameKarachi),
          TimezoneInfo(code: 'Asia/Delhi', name: l10n.timeZoneNameDelhi),
          TimezoneInfo(code: 'Asia/Dhaka', name: l10n.timeZoneNameDhaka),
          TimezoneInfo(code: 'Asia/Colombo', name: l10n.timeZoneNameColombo),
          TimezoneInfo(code: 'Asia/Kathmandu', name: l10n.timeZoneNameKathmandu),
          
          // Merkezi Asya
          TimezoneInfo(code: 'Asia/Almaty', name: l10n.timeZoneNameAlmaty),
          TimezoneInfo(code: 'Asia/Tashkent', name: l10n.timeZoneNameTashkent),
          TimezoneInfo(code: 'Asia/Baku', name: l10n.timeZoneNameBaku),
          TimezoneInfo(code: 'Asia/Yerevan', name: l10n.timeZoneNameYerevan),
          TimezoneInfo(code: 'Asia/Tbilisi', name: l10n.timeZoneNameTbilisi),
        ],
      ),
      TimezoneCategory(
        name: l10n.continentAmerica,
        timezones: [
          // Kuzey Amerika
          TimezoneInfo(code: 'America/New_York', name: l10n.timeZoneNameNewYork),
          TimezoneInfo(code: 'America/Los_Angeles', name: l10n.timeZoneNameLosAngeles),
          TimezoneInfo(code: 'America/Chicago', name: l10n.timeZoneNameChicago),
          TimezoneInfo(code: 'America/Denver', name: l10n.timeZoneNameDenver),
          TimezoneInfo(code: 'America/Phoenix', name: l10n.timeZoneNamePhoenix),
          TimezoneInfo(code: 'America/Toronto', name: l10n.timeZoneNameToronto),
          TimezoneInfo(code: 'America/Vancouver', name: l10n.timeZoneNameVancouver),
          TimezoneInfo(code: 'America/Montreal', name: l10n.timeZoneNameMontreal),
          
          // Güney Amerika
          TimezoneInfo(code: 'America/Sao_Paulo', name: l10n.timeZoneNameSaoPaulo),
          TimezoneInfo(code: 'America/Buenos_Aires', name: l10n.timeZoneNameBuenosAires),
          TimezoneInfo(code: 'America/Mexico_City', name: l10n.timeZoneNameMexicoCity),
          TimezoneInfo(code: 'America/Bogota', name: l10n.timeZoneNameBogota),
          TimezoneInfo(code: 'America/Lima', name: l10n.timeZoneNameLima),
          TimezoneInfo(code: 'America/Santiago', name: l10n.timeZoneNameSantiago),
        ],
      ),
      TimezoneCategory(
        name: l10n.continentAfrica,
        timezones: [
          TimezoneInfo(code: 'Africa/Cairo', name: l10n.timeZoneNameCairo),
          TimezoneInfo(code: 'Africa/Casablanca', name: l10n.timeZoneNameCasablanca),
          TimezoneInfo(code: 'Africa/Lagos', name: l10n.timeZoneNameLagos),
          TimezoneInfo(code: 'Africa/Johannesburg', name: l10n.timeZoneNameJohannesburg),
          TimezoneInfo(code: 'Africa/Nairobi', name: l10n.timeZoneNameNairobi),
          TimezoneInfo(code: 'Africa/Tunis', name: l10n.timeZoneNameTunis),
          TimezoneInfo(code: 'Africa/Algiers', name: l10n.timeZoneNameAlgiers),
        ],
      ),
      TimezoneCategory(
        name: l10n.continentOceania,
        timezones: [
          TimezoneInfo(code: 'Australia/Sydney', name: l10n.timeZoneNameSydney),
          TimezoneInfo(code: 'Australia/Melbourne', name: l10n.timeZoneNameMelbourne),
          TimezoneInfo(code: 'Australia/Brisbane', name: l10n.timeZoneNameBrisbane),
          TimezoneInfo(code: 'Australia/Perth', name: l10n.timeZoneNamePerth),
          TimezoneInfo(code: 'Australia/Adelaide', name: l10n.timeZoneNameAdelaide),
          TimezoneInfo(code: 'Pacific/Auckland', name: l10n.timeZoneNameAuckland),
          TimezoneInfo(code: 'Pacific/Honolulu', name: l10n.timeZoneNameHonolulu),
          TimezoneInfo(code: 'Pacific/Fiji', name: l10n.timeZoneNameFiji),
        ],
      ),
      TimezoneCategory(
        name: l10n.continentAtlantic,
        timezones: [
          TimezoneInfo(code: 'Atlantic/Azores', name: l10n.timeZoneNameAzores),
          TimezoneInfo(code: 'Atlantic/Canary', name: l10n.timeZoneNameCanary),
          TimezoneInfo(code: 'Atlantic/Reykjavik', name: l10n.timeZoneNameReykjavik),
        ],
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final l10n = AppLocalizations.of(context)!;

      _supportedLanguages = _getSupportedLanguages(l10n);

      _supportedCurrencies = {
        'TRY': l10n.currencyNameTRY,
        'USD': l10n.currencyNameUSD,
        'EUR': l10n.currencyNameEUR,
        'GBP': l10n.currencyNameGBP,
      };

      _timezoneCategories = _getTimezoneCategories(l10n);

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_audioService.isPlaying)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  constraints: const BoxConstraints(maxWidth: 150),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(width: 8),
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
            ],
          ),
        );
      },
    );
  }

  // Tüm zaman dilimlerini düz bir liste haline getiren yardımcı fonksiyon
  Map<String, String> _getAllTimezones() {
    Map<String, String> allTimezones = {};
    for (var category in _timezoneCategories) {
      for (var timezone in category.timezones) {
        allTimezones[timezone.code] = timezone.name;
      }
    }
    return allTimezones;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final l10n = AppLocalizations.of(context)!;

        _supportedLanguages = _getSupportedLanguages(l10n);

        _supportedCurrencies = {
          'TRY': l10n.currencyNameTRY,
          'USD': l10n.currencyNameUSD,
          'EUR': l10n.currencyNameEUR,
          'GBP': l10n.currencyNameGBP,
        };

        _timezoneCategories = _getTimezoneCategories(l10n);

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
                      // Dil seçimi - Bayraklarla
                      DropdownButtonFormField<String>(
                        value: _selectedLanguageCode,
                        dropdownColor: Colors.blue.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration.copyWith(
                          labelText: l10n.language,
                          prefixIcon: Icon(Icons.language, color: Colors.white.withOpacity(0.7)),
                        ),
                        items: _supportedLanguages.map((languageInfo) {
                          return DropdownMenuItem<String>(
                            value: languageInfo.code,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  languageInfo.flag,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    languageInfo.name,
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        selectedItemBuilder: (BuildContext context) {
                          return _supportedLanguages.map<Widget>((languageInfo) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  languageInfo.flag,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    languageInfo.name,
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                        onChanged: _onLanguageChanged,
                      ),
                      const SizedBox(height: 20),
                      
                      // Para birimi seçimi
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
                      
                      // Zaman dilimi seçimi - Kategorize edilmiş
                      DropdownButtonFormField<String>(
                        value: _selectedTimezone,
                        isExpanded: true,
                        dropdownColor: Colors.blue.shade800,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration.copyWith(
                          labelText: l10n.businessSettingsTimezoneLabel,
                          prefixIcon: Icon(Icons.access_time_outlined, color: Colors.white.withOpacity(0.7)),
                        ),
                        items: _buildTimezoneDropdownItems(),
                        selectedItemBuilder: (BuildContext context) {
                          final allTimezones = _getAllTimezones();
                          return allTimezones.values.map<Widget>((String item) {
                            return Text(
                              item,
                              style: const TextStyle(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            );
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

  // Kategorize edilmiş zaman dilimi dropdown öğelerini oluşturan fonksiyon
  List<DropdownMenuItem<String>> _buildTimezoneDropdownItems() {
    final l10n = AppLocalizations.of(context)!;
    List<DropdownMenuItem<String>> items = [];
    
    for (int categoryIndex = 0; categoryIndex < _timezoneCategories.length; categoryIndex++) {
      final category = _timezoneCategories[categoryIndex];
      
      // Kategori başlığını ekle
      if (categoryIndex > 0) {
        items.add(
          DropdownMenuItem<String>(
            enabled: false,
            value: null,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              child: Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
            ),
          ),
        );
      }
      
      items.add(
        DropdownMenuItem<String>(
          enabled: false,
          value: null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${l10n.timezoneIconWorld} ${category.name}',
              style: TextStyle(
                color: Colors.amber.shade300,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
      
      // Kategori içindeki zaman dilimlerini ekle
      for (final timezone in category.timezones) {
        items.add(
          DropdownMenuItem<String>(
            value: timezone.code,
            child: Container(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                timezone.name,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }
    }
    
    return items;
  }
}
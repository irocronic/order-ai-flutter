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

  late final AppLocalizations l10n;
  bool _isInitialized = false;

  final Map<String, String> _supportedLanguages = {
    'tr': 'Türkçe',
    'en': 'English',
    'de': 'Deutsch',
    'es': 'Español',
    'ar': 'العربية',
    'it': 'Italiano',
    'zh': '中文',
    'ru': 'Русский',
  };

  final Map<String, String> _supportedCurrencies = {
    'TRY': 'Türk Lirası (₺)',
    'USD': 'ABD Doları (\$)',
    'EUR': 'Euro (€)',
    'GBP': 'İngiliz Sterlini (£)',
  };

  final Map<String, String> _supportedTimezones = {
    'Europe/Istanbul': '(GMT+3) Istanbul',
    'Europe/London': '(GMT+0) London',
    'Europe/Berlin': '(GMT+1) Berlin',
    'America/New_York': '(GMT-5) New York',
    'Asia/Dubai': '(GMT+4) Dubai',
    'Asia/Tokyo': '(GMT+9) Tokyo',
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      l10n = AppLocalizations.of(context)!;
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      _selectedLanguageCode ??=
          languageProvider.currentLocale?.languageCode ?? 'tr';
      _selectedCurrency ??= UserSession.currencyCode ?? 'TRY';
      _selectedTimezone ??= 'Europe/Istanbul';
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;

    try {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      if (_selectedLanguageCode != null) {
        await languageProvider.setLocale(Locale(_selectedLanguageCode!));
      }

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
              content: Text(l10n.setupWizardSettingsSaved), // DÜZELTİLDİ: Bu anahtar artık .arb dosyanızda olmalı.
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

  @override
  Widget build(BuildContext context) {
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
          Text(
            l10n.setupLocalizationDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.4),
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
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedLanguageCode = newValue);
                        _saveSettings();
                      }
                    },
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
          SizedBox(
            height: 60,
            child: AnimatedTextKit(
              // DÜZELTİLDİ: l10n anahtarları yerine sabit metinler kullanılıyor
              animatedTexts: [
                FadeAnimatedText('Hoş geldiniz', textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                FadeAnimatedText('Welcome', textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                FadeAnimatedText('Bienvenido', textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                FadeAnimatedText('Willkommen', textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                FadeAnimatedText('Bienvenue', textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                FadeAnimatedText('Benvenuto', textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                FadeAnimatedText('أهلاً وسهلاً', textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
                FadeAnimatedText('欢迎', textStyle: welcomeTextStyle, duration: const Duration(seconds: 3), textAlign: TextAlign.center),
              ],
              pause: const Duration(milliseconds: 1500),
              repeatForever: true,
            ),
          ),
        ],
      ),
    );
  }
}
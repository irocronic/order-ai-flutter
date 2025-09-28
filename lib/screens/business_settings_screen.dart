// lib/screens/business_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';

class BusinessSettingsScreen extends StatefulWidget {
  final String token;
  final int businessId;

  const BusinessSettingsScreen({
    Key? key,
    required this.token,
    required this.businessId,
  }) : super(key: key);

  @override
  _BusinessSettingsScreenState createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  String? _selectedCurrency;
  String? _selectedTimezone;
  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _isInitialized = false;

  late Map<String, String> _supportedTimezones;
  late Map<String, String> _supportedCurrencies;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final l10n = AppLocalizations.of(context)!;
      
      _supportedCurrencies = {
        'TRY': l10n.currencyNameTRY,
        'USD': l10n.currencyNameUSD,
        'EUR': l10n.currencyNameEUR,
        'GBP': l10n.currencyNameGBP,
      };

      _supportedTimezones = _getSupportedTimezones(l10n);
      
      _fetchBusinessDetails();
      _isInitialized = true;
    }
  }

  Map<String, String> _getSupportedTimezones(AppLocalizations l10n) {
    return {
      // Avrupa
      'Europe/Istanbul': l10n.timeZoneNameIstanbul,
      'Europe/London': l10n.timeZoneNameLondon,
      'Europe/Berlin': l10n.timeZoneNameBerlin,
      'Europe/Paris': l10n.timeZoneNameParis,
      'Europe/Rome': l10n.timeZoneNameRome,
      'Europe/Madrid': l10n.timeZoneNameMadrid,
      'Europe/Amsterdam': l10n.timeZoneNameAmsterdam,
      'Europe/Vienna': l10n.timeZoneNameVienna,
      'Europe/Warsaw': l10n.timeZoneNameWarsaw,
      'Europe/Prague': l10n.timeZoneNamePrague,
      'Europe/Budapest': l10n.timeZoneNameBudapest,
      'Europe/Athens': l10n.timeZoneNameAthens,
      'Europe/Helsinki': l10n.timeZoneNameHelsinki,
      'Europe/Stockholm': l10n.timeZoneNameStockholm,
      'Europe/Oslo': l10n.timeZoneNameOslo,
      'Europe/Copenhagen': l10n.timeZoneNameCopenhagen,
      'Europe/Brussels': l10n.timeZoneNameBrussels,
      'Europe/Zurich': l10n.timeZoneNameZurich,
      'Europe/Moscow': l10n.timeZoneNameMoscow,
      
      // Amerika - Kuzey
      'America/New_York': l10n.timeZoneNameNewYork,
      'America/Los_Angeles': l10n.timeZoneNameLosAngeles,
      'America/Chicago': l10n.timeZoneNameChicago,
      'America/Denver': l10n.timeZoneNameDenver,
      'America/Phoenix': l10n.timeZoneNamePhoenix,
      'America/Toronto': l10n.timeZoneNameToronto,
      'America/Vancouver': l10n.timeZoneNameVancouver,
      'America/Montreal': l10n.timeZoneNameMontreal,
      
      // Amerika - Güney
      'America/Sao_Paulo': l10n.timeZoneNameSaoPaulo,
      'America/Buenos_Aires': l10n.timeZoneNameBuenosAires,
      'America/Mexico_City': l10n.timeZoneNameMexicoCity,
      'America/Bogota': l10n.timeZoneNameBogota,
      'America/Lima': l10n.timeZoneNameLima,
      'America/Santiago': l10n.timeZoneNameSantiago,
      
      // Asya - Doğu
      'Asia/Tokyo': l10n.timeZoneNameTokyo,
      'Asia/Seoul': l10n.timeZoneNameSeoul,
      'Asia/Shanghai': l10n.timeZoneNameShanghai,
      'Asia/Hong_Kong': l10n.timeZoneNameHongKong,
      'Asia/Singapore': l10n.timeZoneNameSingapore,
      'Asia/Bangkok': l10n.timeZoneNameBangkok,
      'Asia/Manila': l10n.timeZoneNameManila,
      'Asia/Jakarta': l10n.timeZoneNameJakarta,
      'Asia/Kuala_Lumpur': l10n.timeZoneNameKualaLumpur,
      'Asia/Ho_Chi_Minh': l10n.timeZoneNameHoChiMinh,
      
      // Asya - Orta & Batı
      'Asia/Dubai': l10n.timeZoneNameDubai,
      'Asia/Riyadh': l10n.timeZoneNameRiyadh,
      'Asia/Qatar': l10n.timeZoneNameQatar,
      'Asia/Kuwait': l10n.timeZoneNameKuwait,
      'Asia/Tehran': l10n.timeZoneNameTehran,
      'Asia/Baghdad': l10n.timeZoneNameBaghdad,
      'Asia/Kabul': l10n.timeZoneNameKabul,
      'Asia/Karachi': l10n.timeZoneNameKarachi,
      'Asia/Delhi': l10n.timeZoneNameDelhi,
      'Asia/Dhaka': l10n.timeZoneNameDhaka,
      'Asia/Colombo': l10n.timeZoneNameColombo,
      'Asia/Kathmandu': l10n.timeZoneNameKathmandu,
      
      // Asya - Merkezi
      'Asia/Almaty': l10n.timeZoneNameAlmaty,
      'Asia/Tashkent': l10n.timeZoneNameTashkent,
      'Asia/Baku': l10n.timeZoneNameBaku,
      'Asia/Yerevan': l10n.timeZoneNameYerevan,
      'Asia/Tbilisi': l10n.timeZoneNameTbilisi,
      
      // Afrika
      'Africa/Cairo': l10n.timeZoneNameCairo,
      'Africa/Casablanca': l10n.timeZoneNameCasablanca,
      'Africa/Lagos': l10n.timeZoneNameLagos,
      'Africa/Johannesburg': l10n.timeZoneNameJohannesburg,
      'Africa/Nairobi': l10n.timeZoneNameNairobi,
      'Africa/Tunis': l10n.timeZoneNameTunis,
      'Africa/Algiers': l10n.timeZoneNameAlgiers,
      
      // Okyanusya
      'Australia/Sydney': l10n.timeZoneNameSydney,
      'Australia/Melbourne': l10n.timeZoneNameMelbourne,
      'Australia/Brisbane': l10n.timeZoneNameBrisbane,
      'Australia/Perth': l10n.timeZoneNamePerth,
      'Australia/Adelaide': l10n.timeZoneNameAdelaide,
      'Pacific/Auckland': l10n.timeZoneNameAuckland,
      'Pacific/Honolulu': l10n.timeZoneNameHonolulu,
      'Pacific/Fiji': l10n.timeZoneNameFiji,
      
      // Atlantik
      'Atlantic/Azores': l10n.timeZoneNameAzores,
      'Atlantic/Canary': l10n.timeZoneNameCanary,
      'Atlantic/Reykjavik': l10n.timeZoneNameReykjavik,
    };
  }

  Future<void> _fetchBusinessDetails() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isLoading = true);
    try {
      final details = await ApiService.fetchBusinessDetails(widget.token, widget.businessId);
      if (mounted) {
        setState(() {
          _selectedCurrency = details['currency_code'] ?? 'TRY';
          _selectedTimezone = details['timezone'] ?? 'Europe/Istanbul';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.businessSettingsErrorLoading(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_selectedCurrency == null || _selectedTimezone == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> dataToUpdate = {
      'currency_code': _selectedCurrency,
      'timezone': _selectedTimezone,
    };

    try {
      await ApiService.updateBusinessSettings(widget.token, widget.businessId, dataToUpdate);

      if (mounted) {
        UserSession.updateCurrencyCode(_selectedCurrency);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.businessSettingsSuccess),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.businessSettingsError(e.toString())),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Build context'te çeviri anahtarları güncelleniyor
    _supportedCurrencies = {
      'TRY': l10n.currencyNameTRY,
      'USD': l10n.currencyNameUSD,
      'EUR': l10n.currencyNameEUR,
      'GBP': l10n.currencyNameGBP,
    };

    _supportedTimezones = _getSupportedTimezones(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.businessSettingsTitle, style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    color: Colors.white.withOpacity(0.9),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.businessSettingsSectionLocalization,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedCurrency,
                            items: _supportedCurrencies.entries.map((entry) {
                              return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedCurrency = value);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: l10n.businessSettingsCurrencyLabel,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedTimezone,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.businessSettingsTimezoneLabel,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: _supportedTimezones.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedTimezone = value);
                              }
                            },
                            validator: (value) => value == null || value.isEmpty ? l10n.businessSettingsTimezoneValidator : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _saveSettings,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3))
                                  : Text(l10n.buttonSave),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}
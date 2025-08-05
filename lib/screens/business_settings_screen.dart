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

  final Map<String, String> _supportedTimezones = {
    'Europe/Istanbul': '(GMT+3) Istanbul',
    'Europe/London': '(GMT+0) London',
    'Europe/Berlin': '(GMT+1) Berlin',
    'America/New_York': '(GMT-5) New York',
    'Asia/Dubai': '(GMT+4) Dubai',
    'Asia/Tokyo': '(GMT+9) Tokyo',
  };

  final Map<String, String> _supportedCurrencies = {
    'TRY': 'Türk Lirası (₺)',
    'USD': 'ABD Doları (\$)',
    'EUR': 'Euro (€)',
    'GBP': 'İngiliz Sterlini (£)',
  };

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _fetchBusinessDetails();
      _isInitialized = true;
    }
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
// lib/screens/payment_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/business_settings_service.dart';
import '../services/user_session.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({Key? key}) : super(key: key);

  @override
  _PaymentSettingsScreenState createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String _errorMessage = '';

  String _selectedProvider = 'none';
  final _apiKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  
  // YENİ: Mevcut anahtarların dolu olup olmadığını takip et
  bool _hasExistingApiKey = false;
  bool _hasExistingSecretKey = false;

  // Desteklenen sağlayıcılar
  final Map<String, String> _supportedProviders = {
    'none': 'Entegrasyon Yok',
    'iyzico': 'Iyzico',
    'paytr': 'PayTR',
  };

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final settings = await BusinessSettingsService.fetchPaymentSettings(
        UserSession.token,
        UserSession.businessId!,
      );
      if (mounted) {
        setState(() {
          _selectedProvider = settings['payment_provider'] ?? 'none';
          _hasExistingApiKey = settings['has_api_key'] ?? false;
          _hasExistingSecretKey = settings['has_secret_key'] ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    
    setState(() => _isLoading = true);
    
    try {
      await BusinessSettingsService.updatePaymentSettings(
        token: UserSession.token,
        businessId: UserSession.businessId!,
        provider: _selectedProvider,
        apiKey: _apiKeyController.text.isNotEmpty ? _apiKeyController.text : null,
        secretKey: _secretKeyController.text.isNotEmpty ? _secretKeyController.text : null,
      );
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.websiteSettingsSuccessSave), backgroundColor: Colors.green)
        );
        Navigator.pop(context);
      }
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.toString().replaceFirst("Exception: ", "")), backgroundColor: Colors.red)
            );
        }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text("Ödeme Ayarları")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedProvider,
                        decoration: const InputDecoration(
                          labelText: 'Ödeme Sağlayıcı',
                          border: OutlineInputBorder(),
                        ),
                        items: _supportedProviders.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedProvider = value;
                              _apiKeyController.clear();
                              _secretKeyController.clear();
                            });
                          }
                        },
                      ),
                      
                      if (_selectedProvider != 'none') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _apiKeyController,
                          decoration: InputDecoration(
                            labelText: '${_supportedProviders[_selectedProvider]} API Anahtarı',
                            border: const OutlineInputBorder(),
                            // YENİ: Mevcut anahtar varsa bilgi göster
                            helperText: _hasExistingApiKey 
                                ? 'Mevcut anahtar kayıtlı. Değiştirmek için yeni anahtar girin.' 
                                : null,
                            helperStyle: TextStyle(color: Colors.green.shade700),
                          ),
                          validator: (value) {
                            // YENİ: Mevcut anahtar varsa zorunlu değil
                            if (_selectedProvider != 'none' && !_hasExistingApiKey && (value == null || value.isEmpty)) {
                              return 'Bu alan zorunludur.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _secretKeyController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: '${_supportedProviders[_selectedProvider]} Gizli Anahtar',
                            border: const OutlineInputBorder(),
                            // YENİ: Mevcut anahtar varsa bilgi göster
                            helperText: _hasExistingSecretKey 
                                ? 'Mevcut anahtar kayıtlı. Değiştirmek için yeni anahtar girin.' 
                                : null,
                            helperStyle: TextStyle(color: Colors.green.shade700),
                          ),
                          validator: (value) {
                            // YENİ: Mevcut anahtar varsa zorunlu değil
                            if (_selectedProvider != 'none' && !_hasExistingSecretKey && (value == null || value.isEmpty)) {
                              return 'Bu alan zorunludur.';
                            }
                            return null;
                          },
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveSettings,
                        child: _isLoading 
                               ? const CircularProgressIndicator(color: Colors.white)
                               : Text(l10n.buttonSaveChanges),
                      ),
                    ],
                  ),
                ),
    );
  }
}
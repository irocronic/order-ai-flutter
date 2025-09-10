// lib/screens/admin_notification_settings_screen.dart

import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../models/notification_event_types.dart'; // Bu dosyayı kullanacağız
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AdminNotificationSettingsScreen extends StatefulWidget {
  final String token;
  const AdminNotificationSettingsScreen({Key? key, required this.token}) : super(key: key);

  @override
  _AdminNotificationSettingsScreenState createState() => _AdminNotificationSettingsScreenState();
}

class _AdminNotificationSettingsScreenState extends State<AdminNotificationSettingsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, bool> _settings = {};
  Map<String, String> _descriptions = {};

  // Sizin yaptığınız sınıflandırmaya göre bildirimleri gruplayalım
  static const List<String> redLightEvents = [
    'guest_order_pending_approval',
    'order_approved_for_kitchen',
    'order_ready_for_pickup_update',
    'order_item_added',
  ];
  static const List<String> yellowLightEvents = [
    'order_preparing_update',
    'order_picked_up_by_waiter',
    'order_out_for_delivery_update',
    'pager_status_updated',
    'stock_adjusted',
  ];
  static const List<String> greenLightEvents = [
    'order_completed_update',
    'order_item_delivered',
    'order_cancelled_update',
    'order_rejected_update',
  ];

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final settingsList = await AdminService.fetchNotificationSettings(widget.token);
      if (mounted) {
        setState(() {
          _settings = {for (var s in settingsList) s['event_type']: s['is_active']};
          _descriptions = {for (var s in settingsList) s['event_type']: s['description']};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateSetting(String eventType, bool newValue) async {
    // UI'da anında güncelleme yap
    setState(() {
      _settings[eventType] = newValue;
    });
    try {
      await AdminService.updateNotificationSetting(widget.token, eventType, newValue);
    } catch (e) {
      // Hata durumunda UI'ı geri al ve hata göster
      if (mounted) {
        setState(() {
          _settings[eventType] = !newValue;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayNames = NotificationEventTypes.getDisplayNames(l10n);

    // Diğer tüm event'leri bulalım
    final otherEvents = _settings.keys.where((key) =>
        !redLightEvents.contains(key) &&
        !yellowLightEvents.contains(key) &&
        !greenLightEvents.contains(key)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Bildirim Ayarları", style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.orangeAccent)))
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      _buildSection(l10n, "Kırmızı Işık (Kritik - Kapatılması Önerilmez)", redLightEvents, displayNames, Colors.red.shade300),
                      _buildSection(l10n, "Sarı Işık (Optimize Edilebilir)", yellowLightEvents, displayNames, Colors.amber.shade300),
                      _buildSection(l10n, "Yeşil Işık (Kapatılması Güvenli)", greenLightEvents, displayNames, Colors.green.shade300),
                      if (otherEvents.isNotEmpty)
                        _buildSection(l10n, "Diğer Bildirimler", otherEvents, displayNames, Colors.grey.shade400),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSection(AppLocalizations l10n, String title, List<String> eventKeys, Map<String, String> displayNames, Color titleColor) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
        children: eventKeys.map((key) {
          return SwitchListTile(
            title: Text(displayNames[key] ?? key, style: const TextStyle(color: Colors.white)),
            subtitle: Text(_descriptions[key] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            value: _settings[key] ?? true,
            onChanged: (newValue) => _updateSetting(key, newValue),
            activeColor: Colors.tealAccent.shade100,
          );
        }).toList(),
      ),
    );
  }
}
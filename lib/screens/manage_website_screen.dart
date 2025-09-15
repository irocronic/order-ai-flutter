// lib/screens/manage_website_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/user_session.dart';
import '../services/website_service.dart';
import '../models/business_website.dart';

class ManageWebsiteScreen extends StatefulWidget {
  const ManageWebsiteScreen({Key? key}) : super(key: key);

  @override
  _ManageWebsiteScreenState createState() => _ManageWebsiteScreenState();
}

class _ManageWebsiteScreenState extends State<ManageWebsiteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String _errorMessage = '';
  BusinessWebsite? _websiteData;

  // Form Controllers
  final Map<String, TextEditingController> _controllers = {
    'about_title': TextEditingController(),
    'about_description': TextEditingController(),
    'about_image': TextEditingController(),
    'contact_phone': TextEditingController(),
    'contact_email': TextEditingController(),
    'contact_address': TextEditingController(),
    'contact_working_hours': TextEditingController(),
    'website_title': TextEditingController(),
    'website_description': TextEditingController(),
    'facebook_url': TextEditingController(),
    'instagram_url': TextEditingController(),
    'twitter_url': TextEditingController(),
  };

  // Switch States
  bool _showMenu = true;
  bool _showContact = true;
  bool _showMap = true;
  bool _allowReservations = false;
  bool _allowOnlineOrdering = false;

  // === HATA DÜZELTME: EKSİK DEĞİŞKENLER EKLENDİ ===
  Color _primaryColor = const Color(0xFF3B82F6);
  Color _secondaryColor = const Color(0xFF10B981);
  // ===============================================

  @override
  void initState() {
    super.initState();
    _fetchWebsiteData();
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchWebsiteData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await WebsiteService.fetchWebsiteDetails(UserSession.token);
      if (mounted) {
        setState(() {
          _websiteData = data;
          _populateForm(data);
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

  void _populateForm(BusinessWebsite data) {
    _controllers['about_title']?.text = data.aboutTitle ?? '';
    _controllers['about_description']?.text = data.aboutDescription ?? '';
    _controllers['about_image']?.text = data.aboutImage ?? '';
    _controllers['contact_phone']?.text = data.contactPhone ?? '';
    _controllers['contact_email']?.text = data.contactEmail ?? '';
    _controllers['contact_address']?.text = data.contactAddress ?? '';
    _controllers['contact_working_hours']?.text = data.contactWorkingHours ?? '';
    _controllers['website_title']?.text = data.websiteTitle ?? '';
    _controllers['website_description']?.text = data.websiteDescription ?? '';
    _controllers['facebook_url']?.text = data.facebookUrl ?? '';
    _controllers['instagram_url']?.text = data.instagramUrl ?? '';
    _controllers['twitter_url']?.text = data.twitterUrl ?? '';
    _showMenu = data.showMenu;
    _showContact = data.showContact;
    _showMap = data.showMap;
    _allowReservations = data.allowReservations;
    _allowOnlineOrdering = data.allowOnlineOrdering;
    _primaryColor = _colorFromHex(data.primaryColor);
    _secondaryColor = _colorFromHex(data.secondaryColor);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final updatedData = BusinessWebsite(
        aboutTitle: _controllers['about_title']!.text,
        aboutDescription: _controllers['about_description']!.text,
        aboutImage: _controllers['about_image']!.text,
        contactPhone: _controllers['contact_phone']!.text,
        contactEmail: _controllers['contact_email']!.text,
        contactAddress: _controllers['contact_address']!.text,
        contactWorkingHours: _controllers['contact_working_hours']!.text,
        websiteTitle: _controllers['website_title']!.text,
        websiteDescription: _controllers['website_description']!.text,
        facebookUrl: _controllers['facebook_url']!.text,
        instagramUrl: _controllers['instagram_url']!.text,
        twitterUrl: _controllers['twitter_url']!.text,
        primaryColor: '#${_primaryColor.value.toRadixString(16).substring(2)}',
        secondaryColor: '#${_secondaryColor.value.toRadixString(16).substring(2)}',
        showMenu: _showMenu,
        showContact: _showContact,
        showMap: _showMap,
        allowReservations: _allowReservations,
        allowOnlineOrdering: _allowOnlineOrdering,
        isActive: _websiteData?.isActive ?? true,
      );

      await WebsiteService.updateWebsiteDetails(
          UserSession.token, updatedData.toJsonForUpdate(
            aboutTitle: updatedData.aboutTitle ?? '',
            aboutDescription: updatedData.aboutDescription ?? '',
            aboutImage: updatedData.aboutImage,
            contactPhone: updatedData.contactPhone ?? '',
            contactEmail: updatedData.contactEmail ?? '',
            contactAddress: updatedData.contactAddress ?? '',
            contactWorkingHours: updatedData.contactWorkingHours ?? '',
            websiteTitle: updatedData.websiteTitle ?? '',
            websiteDescription: updatedData.websiteDescription ?? '',
            facebookUrl: updatedData.facebookUrl ?? '',
            instagramUrl: updatedData.instagramUrl ?? '',
            twitterUrl: updatedData.twitterUrl ?? '',
            primaryColor: updatedData.primaryColor,
            secondaryColor: updatedData.secondaryColor,
            showMenu: updatedData.showMenu,
            showContact: updatedData.showContact,
            showMap: updatedData.showMap,
            allowReservations: updatedData.allowReservations,
            allowOnlineOrdering: updatedData.allowOnlineOrdering,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.websiteSettingsSuccessSave),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  l10n.websiteSettingsErrorSave(e.toString().replaceFirst("Exception: ", ""))),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  void _showColorPicker(BuildContext context, Color initialColor, ValueChanged<Color> onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.websiteSettingsPickColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: onColorChanged,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.dialogButtonDone),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeMenuWebsiteSettings, style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade700, Colors.deepPurple.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildSectionHeader(l10n.websiteSettingsSectionAbout, Icons.info_outline),
                      _buildTextField('about_title', l10n.websiteSettingsLabelAboutTitle),
                      _buildTextField('about_description', l10n.websiteSettingsLabelAboutDesc, maxLines: 4),
                      _buildTextField('about_image', l10n.websiteSettingsLabelAboutImage, icon: Icons.image),

                      _buildSectionHeader(l10n.websiteSettingsSectionContact, Icons.contact_page_outlined),
                      _buildTextField('contact_phone', l10n.websiteSettingsLabelPhone, icon: Icons.phone, keyboardType: TextInputType.phone),
                      _buildTextField('contact_email', l10n.websiteSettingsLabelEmail, icon: Icons.email, keyboardType: TextInputType.emailAddress),
                      _buildTextField('contact_address', l10n.websiteSettingsLabelAddress, icon: Icons.location_on_outlined, maxLines: 2),
                      _buildTextField('contact_working_hours', l10n.websiteSettingsLabelWorkingHours, icon: Icons.access_time),

                      _buildSectionHeader(l10n.websiteSettingsSectionAppearance, Icons.color_lens_outlined),
                      _buildColorPickerTile(l10n.websiteSettingsLabelPrimaryColor, _primaryColor, (color) => setState(() => _primaryColor = color)),
                      _buildColorPickerTile(l10n.websiteSettingsLabelSecondaryColor, _secondaryColor, (color) => setState(() => _secondaryColor = color)),
                      
                      _buildSectionHeader(l10n.websiteSettingsSectionSocial, Icons.share_outlined),
                      _buildTextField('facebook_url', 'Facebook URL', icon: Icons.facebook),
                      _buildTextField('instagram_url', 'Instagram URL', icon: Icons.camera_alt_outlined),
                      _buildTextField('twitter_url', 'Twitter/X URL', icon: Icons.read_more),
                      
                      _buildSectionHeader(l10n.websiteSettingsSectionVisibility, Icons.visibility_outlined),
                      _buildSwitchTile(l10n.websiteSettingsToggleShowMenu, _showMenu, (val) => setState(() => _showMenu = val)),
                      _buildSwitchTile(l10n.websiteSettingsToggleShowContact, _showContact, (val) => setState(() => _showContact = val)),
                      _buildSwitchTile(l10n.websiteSettingsToggleShowMap, _showMap, (val) => setState(() => _showMap = val)),

                      // === YENİ WIDGET'LAR EKLENDİ ===
                      _buildSectionHeader("Online İşlemler", Icons.public),
                      _buildSwitchTile("Online Rezervasyona İzin Ver", _allowReservations, (val) => setState(() => _allowReservations = val)),
                      _buildSwitchTile("Online Siparişe İzin Ver", _allowOnlineOrdering, (val) => setState(() => _allowOnlineOrdering = val)),
                      // ===============================
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveSettings,
        label: Text(l10n.buttonSaveChanges),
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.deepPurple)),
        ],
      ),
    );
  }

  Widget _buildTextField(String key, String label, {int maxLines = 1, IconData? icon, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _controllers[key],
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: icon != null ? Icon(icon) : null,
        ),
      ),
    );
  }

  Widget _buildColorPickerTile(String title, Color color, ValueChanged<Color> onColorChanged) {
    return ListTile(
      title: Text(title),
      trailing: GestureDetector(
        onTap: () => _showColorPicker(context, color, onColorChanged),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey),
          ),
        ),
      ),
      onTap: () => _showColorPicker(context, color, onColorChanged),
    );
  }
  
  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepPurple,
    );
  }
}
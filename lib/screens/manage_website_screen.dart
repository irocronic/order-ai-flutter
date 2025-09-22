// lib/screens/manage_website_screen.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

// HATA ÇÖZÜMÜ:
// 1. Mobil platformlar için dosya işlemleri yapmak üzere 'dart:io' kütüphanesini 'io' takma adıyla import ediyoruz.
import 'dart:io' as io;
// 2. Koşullu import kullanarak:
//    - Eğer platform web ise (dart.library.html true ise), gerçek 'dart:html' kütüphanesini 'html' takma adıyla import ediyoruz.
//    - Eğer platform web değilse, mobil derleyicinin hata vermemesi için oluşturduğumuz sahte (stub) sınıfları içeren dosyayı import ediyoruz.
import 'package:makarna_app/helpers/html_stub.dart' if (dart.library.html) 'dart:html' as html;


import '../models/business_website.dart';
import '../services/api_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/user_session.dart';
import '../services/website_service.dart';
import 'map_picker_screen.dart';

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

  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAboutImage = false;

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
    'map_latitude': TextEditingController(),
    'map_longitude': TextEditingController(),
    'map_zoom_level': TextEditingController(),
  };

  bool _showMenu = true;
  bool _showContact = true;
  bool _showMap = true;
  bool _allowReservations = false;
  bool _allowOnlineOrdering = false;
  String _themeMode = 'system';

  Color _primaryColor = const Color(0xFF3B82F6);
  Color _secondaryColor = const Color(0xFF10B981);

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
    _controllers['map_latitude']?.text = data.mapLatitude?.toString() ?? '';
    _controllers['map_longitude']?.text = data.mapLongitude?.toString() ?? '';
    _controllers['map_zoom_level']?.text = data.mapZoomLevel.toString();

    _showMenu = data.showMenu;
    _showContact = data.showContact;
    _showMap = data.showMap;
    _allowReservations = data.allowReservations;
    _allowOnlineOrdering = data.allowOnlineOrdering;
    _themeMode = data.themeMode;
    _primaryColor = _colorFromHex(data.primaryColor);
    _secondaryColor = _colorFromHex(data.secondaryColor);
  }

  Future<void> _pickAndUploadAboutImage() async {
    if (_isUploadingAboutImage || !mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null || !mounted) return;

    setState(() => _isUploadingAboutImage = true);

    try {
      Uint8List? imageBytes;
      if (kIsWeb) {
        imageBytes = await image.readAsBytes();
      }

      String fileName = p.basename(image.path);
      String firebaseFileName =
          "website_assets/business_${UserSession.businessId}/about_${DateTime.now().millisecondsSinceEpoch}_$fileName";

      final String? downloadUrl = await FirebaseStorageService.uploadImage(
        imageFile: kIsWeb ? null : io.File(image.path),
        imageBytes: imageBytes,
        fileName: firebaseFileName,
        folderPath: 'website_assets',
      );

      if (downloadUrl == null) {
        throw Exception(l10n.photoUploadErrorFirebase);
      }

      if (mounted) {
        setState(() {
          _controllers['about_image']?.text = downloadUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountSettingsSuccessPhotoUpdate),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountSettingsErrorUploadingPhotoGeneric(
                e.toString().replaceFirst("Exception: ", ""))),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAboutImage = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
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
        secondaryColor:
            '#${_secondaryColor.value.toRadixString(16).substring(2)}',
        showMenu: _showMenu,
        showContact: _showContact,
        showMap: _showMap,
        allowReservations: _allowReservations,
        allowOnlineOrdering: _allowOnlineOrdering,
        isActive: _websiteData?.isActive ?? true,
        mapLatitude: _controllers['map_latitude']!.text.isNotEmpty
            ? double.parse(_controllers['map_latitude']!.text)
            : null,
        mapLongitude: _controllers['map_longitude']!.text.isNotEmpty
            ? double.parse(_controllers['map_longitude']!.text)
            : null,
        mapZoomLevel: int.parse(_controllers['map_zoom_level']!.text),
        themeMode: _themeMode,
      );

      await WebsiteService.updateWebsiteDetails(
          UserSession.token,
          updatedData.toJsonForUpdate(
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
            mapLatitude: updatedData.mapLatitude,
            mapLongitude: updatedData.mapLongitude,
            mapZoomLevel: updatedData.mapZoomLevel,
            themeMode: updatedData.themeMode,
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
              content: Text(l10n.websiteSettingsErrorSave(
                  e.toString().replaceFirst("Exception: ", ""))),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openMapPicker() async {
    final currentLat = double.tryParse(_controllers['map_latitude']!.text);
    final currentLng = double.tryParse(_controllers['map_longitude']!.text);

    LatLng initialLatLng = const LatLng(39.9334, 32.8597);
    if (currentLat != null && currentLng != null) {
      initialLatLng = LatLng(currentLat, currentLng);
    }

    final selectedLocation = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (ctx) => MapPickerScreen(initialLocation: initialLatLng),
      ),
    );

    if (selectedLocation != null) {
      setState(() {
        _controllers['map_latitude']?.text =
            selectedLocation.latitude.toStringAsFixed(8);
        _controllers['map_longitude']?.text =
            selectedLocation.longitude.toStringAsFixed(8);
      });
    }
  }

  Color _colorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF$hexColor";
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  void _showColorPicker(BuildContext context, Color initialColor,
      ValueChanged<Color> onColorChanged) {
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

  String _slugify(String text) {
    if (text.isEmpty) return '';
    const Map<String, String> replacements = {
      'ı': 'i', 'ğ': 'g', 'ü': 'u', 'ş': 's', 'ö': 'o', 'ç': 'c',
      'İ': 'i', 'Ğ': 'g', 'Ü': 'u', 'Ş': 's', 'Ö': 'o', 'Ç': 'c'
    };
    
    String slug = text.toLowerCase();
    replacements.forEach((key, value) {
      slug = slug.replaceAll(key, value);
    });

    return slug
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^\w\-]+'), '')
        .replaceAll(RegExp(r'\-\-+'), '-')
        .replaceAll(RegExp(r'^-+'), '')
        .replaceAll(RegExp(r'-+$'), '');
  }

  Future<void> _downloadQrImage(String data, String name) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
      );
      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode;
        final painter = QrPainter.withQr(
          qr: qrCode!,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: false,
        );
        final picData = await painter.toImageData(800);
        if (picData == null) throw Exception("QR kodu oluşturulamadı.");
        final bytes = picData.buffer.asUint8List();
        final fileName =
            '${name}_qr_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';

        if (kIsWeb) {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
        } else {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!status.isGranted) {
              throw Exception("Depolama izni verilmedi.");
            }
          }
          final io.Directory? dir = await getDownloadsDirectory();
          if (dir == null) throw Exception("İndirilenler klasörü bulunamadı.");
          final filePath = '${dir.path}/$fileName';
          final file = io.File(filePath);
          await file.writeAsBytes(bytes);

          final result = await OpenFile.open(filePath);
          if (result.type != ResultType.done) {
            throw Exception("Dosya açılamadı: ${result.message}");
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.manageTablesSuccessQrDownloaded),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.manageTablesErrorQrDownload(e.toString())),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showQrDialog(BuildContext context, String websiteLink) async {
    final l10n = AppLocalizations.of(context)!;

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Web Sitesi QR Kodu",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 250,
            height: 350,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                QrImageView(
                  data: websiteLink,
                  version: QrVersions.auto,
                  size: 200.0,
                  gapless: false,
                  errorStateBuilder: (cxt, err) {
                    return Center(
                      child: Text(
                        dialogL10n.manageTablesErrorCreatingQr,
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                SelectableText(
                  websiteLink,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: Text(dialogL10n.manageTablesButtonDownloadQr),
                  onPressed: () => _downloadQrImage(websiteLink, "website"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              child: Text(dialogL10n.dialogButtonClose,
                  style: const TextStyle(
                      color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeMenuWebsiteSettings,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade700, Colors.purple.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_outlined, color: Colors.white),
            tooltip: "Web Sitesi QR Kodu",
            onPressed: _isLoading
                ? null
                : () {
                    final businessName = UserSession.username;
                    if (businessName != null && businessName.isNotEmpty) {
                      final businessSlug = _slugify(businessName);
                      final uri = Uri.parse(ApiService.baseUrl.replaceAll('/api', ''));
                      final websiteLink =
                          '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/website/$businessSlug/';
                      _showQrDialog(context, websiteLink);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                "İşletme adı bulunamadı, QR kod oluşturulamıyor."),
                            backgroundColor: Colors.orange),
                      );
                    }
                  },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade700.withOpacity(0.9),
              Colors.purple.shade500.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(_errorMessage,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16)))
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      child: Card(
                        color: Colors.white.withOpacity(0.95),
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                  l10n.websiteSettingsSectionAbout,
                                  Icons.info_outline),
                              _buildTextField('about_title',
                                  l10n.websiteSettingsLabelAboutTitle),
                              _buildTextField('about_description',
                                  l10n.websiteSettingsLabelAboutDesc,
                                  maxLines: 4),
                              const SizedBox(height: 8),
                              _buildImagePicker(
                                label: l10n.websiteSettingsLabelAboutImage,
                                controller: _controllers['about_image']!,
                                onUpload: _pickAndUploadAboutImage,
                                isUploading: _isUploadingAboutImage,
                              ),
                              const SizedBox(height: 16),
                              _buildSectionHeader(
                                  l10n.websiteSettingsSectionContact,
                                  Icons.contact_page_outlined),
                              _buildTextField(
                                  'contact_phone', l10n.websiteSettingsLabelPhone,
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone),
                              _buildTextField(
                                  'contact_email', l10n.websiteSettingsLabelEmail,
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress),
                              _buildTextField('contact_address',
                                  l10n.websiteSettingsLabelAddress,
                                  icon: Icons.location_on_outlined,
                                  maxLines: 2),
                              _buildTextField('contact_working_hours',
                                  l10n.websiteSettingsLabelWorkingHours,
                                  icon: Icons.access_time),
                              _buildSectionHeader(
                                  "Harita Ayarları", Icons.map_outlined),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                        'map_latitude', "Enlem (Latitude)",
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                                decimal: true, signed: true),
                                        validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final latitude = double.tryParse(value);
                                        if (latitude == null ||
                                            latitude < -90 ||
                                            latitude > 90) {
                                          return "Geçerli bir enlem girin (-90 ile 90)";
                                        }
                                      }
                                      return null;
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildTextField('map_longitude',
                                        "Boylam (Longitude)",
                                        keyboardType: const TextInputType
                                            .numberWithOptions(
                                                decimal: true, signed: true),
                                        validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final longitude =
                                            double.tryParse(value);
                                        if (longitude == null ||
                                            longitude < -180 ||
                                            longitude > 180) {
                                          return "Geçerli bir boylam girin (-180 ile 180)";
                                        }
                                      }
                                      return null;
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: _openMapPicker,
                                  icon: const Icon(Icons.map),
                                  label: const Text("Haritadan Konum Seç"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.deepPurple.shade100,
                                    foregroundColor:
                                        Colors.deepPurple.shade900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                  'map_zoom_level', "Harita Zoom Seviyesi (1-20)",
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Zoom seviyesi gereklidir";
                                }
                                final zoom = int.tryParse(value);
                                if (zoom == null || zoom < 1 || zoom > 20) {
                                  return "Geçerli bir zoom seviyesi girin (1-20)";
                                }
                                return null;
                              }),
                              _buildSectionHeader(
                                  l10n.websiteSettingsSectionAppearance,
                                  Icons.color_lens_outlined),
                              _buildThemeSelector(),
                              _buildColorPickerTile(
                                  l10n.websiteSettingsLabelPrimaryColor,
                                  _primaryColor,
                                  (color) =>
                                      setState(() => _primaryColor = color)),
                              _buildColorPickerTile(
                                  l10n.websiteSettingsLabelSecondaryColor,
                                  _secondaryColor,
                                  (color) =>
                                      setState(() => _secondaryColor = color)),
                              _buildSectionHeader(l10n.websiteSettingsSectionSocial,
                                  Icons.share_outlined),
                              _buildTextField('facebook_url', 'Facebook URL',
                                  icon: Icons.facebook),
                              _buildTextField(
                                  'instagram_url', 'Instagram URL',
                                  icon: Icons.camera_alt_outlined),
                              _buildTextField('twitter_url', 'Twitter/X URL',
                                  icon: Icons.read_more),
                              _buildSectionHeader(
                                  l10n.websiteSettingsSectionVisibility,
                                  Icons.visibility_outlined),
                              _buildSwitchTile(
                                  l10n.websiteSettingsToggleShowMenu,
                                  _showMenu,
                                  (val) => setState(() => _showMenu = val)),
                              _buildSwitchTile(
                                  l10n.websiteSettingsToggleShowContact,
                                  _showContact,
                                  (val) => setState(() => _showContact = val)),
                              _buildSwitchTile(l10n.websiteSettingsToggleShowMap,
                                  _showMap, (val) => setState(() => _showMap = val)),
                              _buildSectionHeader(
                                  "Online İşlemler", Icons.public),
                              _buildSwitchTile(
                                  "Online Rezervasyona İzin Ver",
                                  _allowReservations,
                                  (val) =>
                                      setState(() => _allowReservations = val)),
                              _buildSwitchTile(
                                  "Online Siparişe İzin Ver",
                                  _allowOnlineOrdering,
                                  (val) => setState(
                                      () => _allowOnlineOrdering = val)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveSettings,
        label: Text(l10n.buttonSaveChanges),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildThemeSelector() {
    final Map<String, String> themeOptions = {
      'system': "Sistem Varsayılanı",
      'light': "Aydınlık Mod",
      'dark': "Karanlık Mod",
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _themeMode,
        decoration: InputDecoration(
          labelText: "Web Sitesi Teması",
          labelStyle: TextStyle(color: Colors.grey.shade700),
          prefixIcon:
              Icon(Icons.brightness_6_outlined, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.black.withOpacity(0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple.shade700, width: 2),
          ),
        ),
        items: themeOptions.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _themeMode = newValue;
            });
          }
        },
        onSaved: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _themeMode = newValue;
            });
          }
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple.shade700),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.deepPurple.shade900,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String key,
    String label, {
    int maxLines = 1,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _controllers[key],
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade700),
          prefixIcon:
              icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
          filled: true,
          fillColor: Colors.black.withOpacity(0.04),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.deepPurple.shade700, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required TextEditingController controller,
    required Future<void> Function() onUpload,
    required bool isUploading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isUploading ? null : onUpload,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    if (value.text.isEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: Colors.grey.shade600, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            "Görsel Yükle",
                            style: TextStyle(color: Colors.grey.shade700),
                          )
                        ],
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: FadeInImage.memoryNetwork(
                        placeholder: kTransparentImage,
                        image: value.text,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 150,
                        imageErrorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image,
                                color: Colors.red, size: 40),
                      ),
                    );
                  },
                ),
                if (isUploading)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPickerTile(
      String title, Color color, ValueChanged<Color> onColorChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      title: Text(title),
      trailing: GestureDetector(
        onTap: () => _showColorPicker(context, color, onColorChanged),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
      onTap: () => _showColorPicker(context, color, onColorChanged),
    );
  }

  Widget _buildSwitchTile(
      String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepPurple.shade700,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

final Uint8List kTransparentImage = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);
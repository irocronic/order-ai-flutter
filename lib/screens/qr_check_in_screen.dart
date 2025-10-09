// lib/screens/qr_check_in_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';
import '../services/user_session.dart';
import '../services/offline_attendance_service.dart';
import '../services/connectivity_service.dart';
import '../models/attendance_record.dart';
import '../models/check_in_location.dart';
import 'package:geolocator/geolocator.dart';

class QRCheckInScreen extends StatefulWidget {
  const QRCheckInScreen({Key? key}) : super(key: key);

  @override
  _QRCheckInScreenState createState() => _QRCheckInScreenState();
}

class _QRCheckInScreenState extends State<QRCheckInScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  String _statusMessage = '';
  Map<String, dynamic>? _currentStatus;
  Position? _currentPosition;
  CheckInLocation? _detectedLocation;
  bool _isOnline = true;
  bool _scannerStarted = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
    _checkConnectivity();
    _getCurrentLocation();
    _initializeScanner();
  }

  void _initializeScanner() {
    _controller = MobileScannerController();
    _scannerStarted = true;
  }

  Future<void> _checkConnectivity() async {
    _isOnline = await ConnectivityService.instance.isOnline;
    if (_isOnline) {
      OfflineAttendanceService.autoSyncIfOnline();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await LocationService.getCurrentLocation();
      setState(() {});
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _loadCurrentStatus() async {
    try {
      final status = await AttendanceService.getCurrentAttendanceStatus(UserSession.token);
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    } catch (e) {
      debugPrint('Current status load error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isProcessing && capture.barcodes.isNotEmpty) {
      final String? qrData = capture.barcodes.first.rawValue;
      if (qrData != null) {
        _processQRCode(qrData);
      }
    }
  }

  Future<void> _processQRCode(String qrData) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'QR kod işleniyor...';
    });

    try {
      if (_currentPosition == null) {
        _currentPosition = await LocationService.getCurrentLocation();
        if (_currentPosition == null) {
          throw Exception('Konum alınamadı. Lütfen konum servislerini aktif edin.');
        }
      }

      if (_isOnline) {
        await _processOnlineCheckIn(qrData, _currentPosition!);
      } else {
        await _processOfflineCheckIn(qrData, _currentPosition!);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Hata: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Yeniden Dene',
              textColor: Colors.white,
              onPressed: () => _processQRCode(qrData),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processOnlineCheckIn(String qrData, Position position) async {
    try {
      AttendanceRecord record = await AttendanceService.recordAttendanceWithQR(
        UserSession.token,
        qrData,
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _statusMessage = record.type == AttendanceType.checkIn
              ? '✅ Giriş başarıyla kaydedildi!'
              : '✅ Çıkış başarıyla kaydedildi!';
        });

        await _loadCurrentStatus();
        await _showSuccessDialog(record);
      }
    } catch (e) {
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        await _processOfflineCheckIn(qrData, position);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _processOfflineCheckIn(String qrData, Position position) async {
    if (!_validateQRFormat(qrData)) {
      throw Exception('Geçersiz QR kod formatı');
    }

    final offlineRecord = {
      'qr_data': qrData,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'user_id': UserSession.userId,
      'type': _determineAttendanceType(),
    };

    await OfflineAttendanceService.saveOfflineRecord(offlineRecord);

    if (mounted) {
      setState(() {
        _statusMessage = '📱 Offline kayıt oluşturuldu!\nİnternet bağlantısı kurulduğunda senkronize edilecek.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Offline Kayıt Oluşturuldu'),
              Text('İnternet bağlantısı kurulduğunda otomatik senkronize edilecek.'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  String _determineAttendanceType() {
    if (_currentStatus != null && _currentStatus!['is_checked_in'] == true) {
      return 'check_out';
    }
    return 'check_in';
  }

  bool _validateQRFormat(String qrData) {
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
    return uuidRegex.hasMatch(qrData.toLowerCase());
  }

  Future<void> _showSuccessDialog(AttendanceRecord record) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          record.type == AttendanceType.checkIn ? Icons.login : Icons.logout,
          color: record.type == AttendanceType.checkIn ? Colors.green : Colors.orange,
          size: 48,
        ),
        title: Text(
          record.type == AttendanceType.checkIn ? 'Giriş Başarılı' : 'Çıkış Başarılı',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Zaman: ${record.timestamp.toString().split('.')[0]}'),
            if (record.checkInLocationId != null)
              Text('Lokasyon ID: ${record.checkInLocationId}'),
            const SizedBox(height: 8),
            Text(
              'Kayıt başarıyla sisteme işlendi.',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFeedback() {
    if (_currentPosition == null || _detectedLocation == null) {
      return const SizedBox.shrink();
    }

    final distance = LocationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _detectedLocation!.latitude,
      _detectedLocation!.longitude,
    );

    final isWithinRadius = distance <= _detectedLocation!.radiusMeters;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWithinRadius ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWithinRadius ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            isWithinRadius ? Icons.check_circle : Icons.error,
            color: isWithinRadius ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            isWithinRadius 
                ? '✅ Konumunuz uygun (${distance.toInt()}m uzaklıkta)'
                : '❌ Konumunuz uygun değil (${distance.toInt()}m uzaklıkta)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isWithinRadius ? Colors.green : Colors.red,
            ),
          ),
          Text(
            'Gerekli yarıçap: ${_detectedLocation!.radiusMeters.toInt()} metre',
            style: const TextStyle(fontSize: 12),
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
        title: const Text(
          'QR ile Giriş-Çıkış',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.wifi : Icons.wifi_off,
                  color: _isOnline ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _isOnline ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Durum Bilgisi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                if (_currentStatus != null) ...[
                  Text(
                    _currentStatus!['is_checked_in'] == true 
                        ? '🟢 İşyerinde bulunuyorsunuz'
                        : '🔴 İşyerinde değilsiniz',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _currentStatus!['is_checked_in'] == true 
                          ? Colors.green.shade700 
                          : Colors.red.shade700,
                    ),
                  ),
                  if (_currentStatus!['last_check_in'] != null)
                    Text(
                      'Son giriş: ${_currentStatus!['last_check_in']}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                ],
                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _statusMessage.contains('✅') 
                            ? Colors.green.shade700 
                            : _statusMessage.contains('📱')
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          
          // Location feedback
          _buildLocationFeedback(),
          
          // QR Scanner - Düzeltilmiş version
          Expanded(
            child: Stack(
              children: [
                if (_scannerStarted && _controller != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(
                      controller: _controller!,
                      onDetect: _onDetect,
                    ),
                  ),
                
                // Özel overlay (tarama alanını göstermek için)
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blue,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Köşe işaretleri
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.blue, width: 4),
                                left: BorderSide(color: Colors.blue, width: 4),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.blue, width: 4),
                                right: BorderSide(color: Colors.blue, width: 4),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.blue, width: 4),
                                left: BorderSide(color: Colors.blue, width: 4),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.blue, width: 4),
                                right: BorderSide(color: Colors.blue, width: 4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Loading Overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'İşleniyor...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Alt bilgi
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                const Text(
                  'QR kodu kameranın karşısına tutun.\nGPS lokasyonunuz kontrol edilecektir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                if (!_isOnline) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '📶 İnternet bağlantısı yok. Giriş-çıkış offline kaydedilecek.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                // Offline kayıt sayısı göster
                FutureBuilder<int>(
                  future: OfflineAttendanceService.getOfflineRecordCount(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data! > 0) {
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '📋 ${snapshot.data} kayıt senkronizasyon bekliyor',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
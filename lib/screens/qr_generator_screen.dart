// lib/screens/qr_generator_screen.dart
import 'dart:convert'; // JSON için gerekli import
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/check_in_location.dart';
import '../services/attendance_service.dart';
import '../services/user_session.dart';

class QRGeneratorScreen extends StatefulWidget {
  final List<CheckInLocation> locations;

  const QRGeneratorScreen({Key? key, required this.locations}) : super(key: key);

  @override
  _QRGeneratorScreenState createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  CheckInLocation? _selectedLocation;
  String? _qrData;
  bool _isGenerating = false;
  Map<String, String> _allQRCodes = {}; // Tüm lokasyonlar için QR kodlar

  Future<void> _generateQRCode() async {
    if (_selectedLocation == null) return;
    
    setState(() {
      _isGenerating = true;
    });

    try {
      final qrData = await AttendanceService.generateQRCode(
        UserSession.token,
        _selectedLocation!.id,
      );
      
      if (mounted) {
        setState(() {
          _qrData = qrData;
          _allQRCodes[_selectedLocation!.name] = qrData;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR kod oluşturulamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // 🔧 YENİ ÖZELLİK: Tüm aktif lokasyonlar için QR kod üret
  Future<void> _generateQRCodesForAllLocations() async {
    final activeLocations = widget.locations.where((l) => l.isActive).toList();
    
    if (activeLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktif lokasyon bulunamadı'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final results = <String, String>{};
      int successCount = 0;
      int failureCount = 0;
      
      for (final location in activeLocations) {
        try {
          final qrData = await AttendanceService.generateQRCode(
            UserSession.token,
            location.id,
          );
          results[location.name] = qrData;
          successCount++;
        } catch (e) {
          failureCount++;
          debugPrint('Failed to generate QR for ${location.name}: $e');
        }
      }
      
      setState(() {
        _allQRCodes = results;
      });

      // Sonuç göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR Kod Üretimi Tamamlandı\n'
              'Başarılı: $successCount, Başarısız: $failureCount'
            ),
            backgroundColor: failureCount == 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Toplu paylaşım teklif et
      if (results.isNotEmpty) {
        _showBulkShareDialog(results);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toplu QR kod oluşturma hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _showBulkShareDialog(Map<String, String> qrCodes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu Paylaşım'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${qrCodes.length} adet QR kod oluşturuldu.'),
            const SizedBox(height: 16),
            const Text('Bu kodları nasıl paylaşmak istiyorsunuz?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _shareAllQRCodes(qrCodes);
            },
            child: const Text('Metin Olarak'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportQRCodesAsJson(qrCodes);
            },
            child: const Text('JSON Olarak'),
          ),
        ],
      ),
    );
  }

  void _shareQRCode() {
    if (_qrData != null && _selectedLocation != null) {
      Share.share(
        'İşyeri giriş-çıkış QR kodu:\n\n'
        'Lokasyon: ${_selectedLocation!.name}\n'
        'QR Data: $_qrData\n\n'
        'Bu kodu mobil uygulamada taratarak giriş-çıkış yapabilirsiniz.',
        subject: 'İşyeri Giriş-Çıkış QR Kodu',
      );
    }
  }

  void _shareAllQRCodes(Map<String, String> qrCodes) {
    final buffer = StringBuffer();
    buffer.writeln('İşyeri Giriş-Çıkış QR Kodları');
    buffer.writeln('=' * 40);
    buffer.writeln();
    
    qrCodes.forEach((locationName, qrData) {
      buffer.writeln('📍 Lokasyon: $locationName');
      buffer.writeln('🔗 QR Data: $qrData');
      buffer.writeln();
    });
    
    buffer.writeln('Bu kodları mobil uygulamada taratarak giriş-çıkış yapabilirsiniz.');
    buffer.writeln('Üretim Tarihi: ${DateTime.now().toString().split('.')[0]}');

    Share.share(
      buffer.toString(),
      subject: 'İşyeri QR Kodları (${qrCodes.length} adet)',
    );
  }

  void _exportQRCodesAsJson(Map<String, String> qrCodes) {
    final jsonData = {
      'generated_at': DateTime.now().toIso8601String(),
      'business_id': UserSession.businessId,
      'total_codes': qrCodes.length,
      'qr_codes': qrCodes.entries.map((entry) => {
        'location_name': entry.key,
        'qr_data': entry.value,
      }).toList(),
    };

    final jsonString = jsonEncode(jsonData);
    
    Share.share(
      jsonString,
      subject: 'QR Codes Export - ${DateTime.now().toString().split(' ')[0]}.json',
    );
  }

  void _copyQRData() {
    if (_qrData != null) {
      Clipboard.setData(ClipboardData(text: _qrData!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR kod verisi kopyalandı'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // 🔧 YENİ ÖZELLİK: QR kod geçerlilik süresi gösterimi
  Widget _buildQRValidityInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'QR Kod Geçerlik Bilgisi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• QR kodlar 24 saat geçerlidir\n'
            '• Her gün yeni kodlar üretilmelidir\n'
            '• Süresi dolan kodlar otomatik iptal edilir',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR Kod Üreteci',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade900, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // 🔧 YENİ: Toplu üretim butonu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'bulk_generate') {
                _generateQRCodesForAllLocations();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'bulk_generate',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2),
                    SizedBox(width: 8),
                    Text('Tümü İçin Üret'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.shade900.withOpacity(0.9),
              Colors.purple.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  color: Colors.white.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lokasyon Seçin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<CheckInLocation>(
                          value: _selectedLocation,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Bir lokasyon seçin',
                          ),
                          items: widget.locations.where((l) => l.isActive).map((location) {
                            return DropdownMenuItem(
                              value: location,
                              child: Text(location.name),
                            );
                          }).toList(),
                          onChanged: (CheckInLocation? value) {
                            setState(() {
                              _selectedLocation = value;
                              _qrData = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _selectedLocation == null || _isGenerating 
                                    ? null 
                                    : _generateQRCode,
                                child: _isGenerating
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('QR Kod Üret'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // QR Kod Geçerlik Bilgisi
                _buildQRValidityInfo(),
                
                if (_qrData != null) ...[
                  Card(
                    margin: const EdgeInsets.all(16),
                    color: Colors.white.withOpacity(0.9),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            _selectedLocation!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          QrImageView(
                            data: _qrData!,
                            version: QrVersions.auto,
                            size: 250,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Üretim: ${DateTime.now().toString().split('.')[0]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _copyQRData,
                                icon: const Icon(Icons.copy),
                                label: const Text('Kopyala'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _shareQRCode,
                                icon: const Icon(Icons.share),
                                label: const Text('Paylaş'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Tüm QR kodlar listesi (eğer toplu üretim yapıldıysa)
                if (_allQRCodes.isNotEmpty && _allQRCodes.length > 1) ...[
                  Card(
                    margin: const EdgeInsets.all(16),
                    color: Colors.white.withOpacity(0.9),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tüm QR Kodlar (${_allQRCodes.length} adet)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Spread operator düzeltildi
                          ..._allQRCodes.entries.map((entry) => 
                            ListTile(
                              leading: const Icon(Icons.qr_code),
                              title: Text(entry.key),
                              subtitle: Text('${entry.value.substring(0, 8)}...'),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: entry.value));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${entry.key} QR kodu kopyalandı')),
                                  );
                                },
                              ),
                            ),
                          ).toList(),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _shareAllQRCodes(_allQRCodes),
                              icon: const Icon(Icons.share),
                              label: const Text('Tümünü Paylaş'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
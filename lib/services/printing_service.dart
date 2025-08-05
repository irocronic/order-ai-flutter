// lib/services/printing_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_discovery/network_discovery.dart';
import '../models/printer_config.dart';
import '../models/discovered_printer.dart';

class PrintingService {
  /// Ağdaki ESC/POS destekli yazıcıları keşfeder.
  /// Web platformunda bu işlem desteklenmez ve bir hata fırlatır.
  static Future<List<DiscoveredPrinter>> discoverPrinters() async {
    if (kIsWeb) {
      debugPrint("[PrintingService] Web'de otomatik yazıcı keşfi denendi. Bu desteklenmiyor.");
      // Kullanıcıya web'de bu özelliğin neden çalışmadığını açıklayan bir hata fırlatmak en iyisidir.
      // Bu sayede UI katmanı bu hatayı yakalayıp kullanıcıya "Lütfen manuel ekleyin" gibi bir mesaj gösterebilir.
      throw UnsupportedError(
          "Web'de otomatik yazıcı bulma desteklenmemektedir. Lütfen yazıcı IP'sini manuel olarak ekleyin.");
    }

    final List<DiscoveredPrinter> devices = [];
    final info = NetworkInfo();
    final String? wifiIP = await info.getWifiIP();

    if (wifiIP == null) {
      throw Exception("Wi-Fi bağlantısı bulunamadı. Lütfen Wi-Fi'ye bağlı olduğunuzdan emin olun.");
    }

    final String subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    const int port = 9100; // Standart yazıcı portu

    debugPrint('Ağ taranıyor: $subnet ...');

    final stream = NetworkDiscovery.discover(subnet, port);

    // Stream'i dinleyerek bulunan ve belirtilen portu açık olan cihazları listeye ekle
    await for (NetworkAddress addr in stream) {
      debugPrint('Bulunan Cihaz: ${addr.ip}');
      devices.add(DiscoveredPrinter(
        host: addr.ip,
        name: 'Ağ Yazıcısı', // Cihaz adı bu yöntemle alınamaz, IP'yi kullanırız.
      ));
    }

    debugPrint("${devices.length} adet potansiyel yazıcı bulundu.");
    return devices;
  }

  /// Belirtilen IP adresindeki yazıcıya test verisi gönderir.
  static Future<bool> testPrint(String printerIp) async {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load(); // <<< GÜNCELLENDİ
    final printer = NetworkPrinter(paper, profile);
    final PosPrintResult res = await printer.connect(printerIp, port: 9100);

    if (res == PosPrintResult.success) {
      printer.text('Yazici Testi Basarili!', styles: const PosStyles(align: PosAlign.center, bold: true));
      printer.feed(2);
      printer.cut();
      printer.disconnect();
      return true;
    } else {
      debugPrint('Test Print Result: ${res.msg}');
      return false;
    }
  }

  /// Oluşturulmuş bilet/fiş byte'larını belirli bir yazıcıya gönderir.
  static Future<bool> printTicket(List<int> ticketBytes, PrinterConfig printerConfig) async {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load(); // <<< GÜNCELLENDİ
    final printer = NetworkPrinter(paper, profile);
    final PosPrintResult res = await printer.connect(printerConfig.ipAddress, port: printerConfig.port);

    if (res == PosPrintResult.success) {
      printer.rawBytes(ticketBytes);
      printer.disconnect();
      return true;
    } else {
      debugPrint('Print Ticket Result: ${res.msg}');
      throw Exception('Yazıcıya bağlanılamadı: ${res.msg}');
    }
  }
}
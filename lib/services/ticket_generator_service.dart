// lib/services/ticket_generator_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'dart:convert'; // utf8 için gerekli olan kütüphane
import '../../models/order.dart' as app_order;
import '../models/order_item.dart';
import '../models/menu_item.dart';
import '../models/menu_item_variant.dart';
import 'api_service.dart';

class TicketGeneratorService {

  /// Mutfak için sipariş fişi oluşturur.
  static Future<List<int>> generateKitchenTicket(app_order.Order order) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.setGlobalCodeTable('CP857');

    bytes += generator.textEncoded(
      utf8.encode('MASA: ${order.table ?? 'PAKET'} #${order.id}'),
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.hr();

    for (var item in order.orderItems) {
      String mainLine = '${item.quantity}x ${item.menuItem.name}';
      if (item.variant != null) {
        mainLine += ' (${item.variant!.name})';
      }
      bytes += generator.textEncoded(utf8.encode(mainLine), styles: const PosStyles(bold: true, height: PosTextSize.size2));
      
      if(item.extras != null && item.extras!.isNotEmpty) {
        for (var extra in item.extras!) {
           bytes += generator.textEncoded(utf8.encode('  + ${extra.name}'), styles: const PosStyles(bold: false, height: PosTextSize.size1));
        }
      }
      bytes += generator.text('--------------------------------', styles: const PosStyles(align: PosAlign.center));
    }
    
    bytes += generator.text(DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), styles: const PosStyles(align: PosAlign.right));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Müşteri için ödeme fişi (adisyon) oluşturur.
  static Future<List<int>> generateCustomerReceipt(app_order.Order order, String businessName) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    // GÜNCELLENDİ: Değişken adı KDV hariç tutarı temsil edecek şekilde değiştirildi.
    double subTotal = 0.0;

    bytes += generator.setGlobalCodeTable('CP857');

    // Header
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.textEncoded(utf8.encode(businessName), styles: const PosStyles(bold: true, height: PosTextSize.size2));
    bytes += generator.textEncoded(utf8.encode('ADİSYON'), styles: const PosStyles(bold: true));
    bytes += generator.hr();
    bytes += generator.text('Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}');
    bytes += generator.textEncoded(utf8.encode(order.orderType == 'table' ? 'Masa: ${order.table}' : 'Paket Sipariş'));
    bytes += generator.text('Siparis No: #${order.id}');
    bytes += generator.hr();

    // Items
    bytes += generator.row([
      PosColumn(textEncoded: utf8.encode('Ürün'), width: 5, styles: const PosStyles(bold: true)),
      PosColumn(textEncoded: utf8.encode('Adet'), width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
      // GÜNCELLENDİ: Sütun başlığı "Fiyat" olarak değiştirildi (Birim Fiyat)
      PosColumn(textEncoded: utf8.encode('Fiyat'), width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(textEncoded: utf8.encode('Tutar'), width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.hr(ch: '-');

    for (var item in order.orderItems) {
      String itemTitle = item.menuItem.name;
      if (item.variant != null) {
        itemTitle += '\n (${item.variant!.name})';
      }
      if (item.extras != null && item.extras!.isNotEmpty) {
        itemTitle += '\n' + item.extras!.map((e) => '+${e.name}').join(', ');
      }
      final itemTotal = item.price * item.quantity;
      // GÜNCELLENDİ: `total` yerine `subTotal` kullanılıyor.
      subTotal += itemTotal;
      bytes += generator.row([
        PosColumn(textEncoded: utf8.encode(itemTitle), width: 5),
        PosColumn(text: item.quantity.toString(), width: 2, styles: const PosStyles(align: PosAlign.center)),
        // YENİ: KDV hariç birim fiyat sütunu eklendi
        PosColumn(text: item.price.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: itemTotal.toStringAsFixed(2), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();

    // GÜNCELLENDİ: Total bölümü KDV detaylarını içerecek şekilde güncellendi
    // Ara Toplam (KDV Hariç)
    bytes += generator.row([
      PosColumn(textEncoded: utf8.encode('Ara Toplam'), width: 7, styles: const PosStyles(bold: true)),
      PosColumn(text: '${subTotal.toStringAsFixed(2)} TL', width: 5, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    // Toplam KDV
    bytes += generator.row([
      PosColumn(textEncoded: utf8.encode('Toplam KDV'), width: 7, styles: const PosStyles(bold: true)),
      PosColumn(text: '${order.totalKdvAmount?.toStringAsFixed(2) ?? '0.00'} TL', width: 5, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.hr(ch: '=');
    // Genel Toplam (KDV Dahil)
    bytes += generator.row([
      PosColumn(textEncoded: utf8.encode('GENEL TOPLAM'), width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: '${order.grandTotal?.toStringAsFixed(2) ?? '0.00'} TL', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
    ]);
    bytes += generator.hr();

    // Footer
    bytes += generator.textEncoded(utf8.encode('Bizi tercih ettiğiniz için teşekkür ederiz!'), styles: const PosStyles(align: PosAlign.center));
    
    if(order.uuid != null && order.uuid!.isNotEmpty) {
      final uri = Uri.parse(ApiService.baseUrl.replaceAll('/api', ''));
      final guestLink = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/guest/takeaway/${order.uuid}/';
      bytes += generator.feed(1);
      bytes += generator.textEncoded(utf8.encode('Siparişinize ekleme yapmak için:'), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.qrcode(guestLink);
    }
    
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}
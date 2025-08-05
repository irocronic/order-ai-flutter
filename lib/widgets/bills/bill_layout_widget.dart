// lib/widgets/bills/bill_layout_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:collection/collection.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../models/order.dart' as app_order;

// YENİ: Gerekli import eklendi
import 'dart:convert'; 

import '../../models/menu_item.dart';
import '../../models/menu_item_variant.dart';
import '../../services/api_service.dart';

class BillLayoutWidget extends StatelessWidget {
  final dynamic orderData;
  final String businessName;
  final List<MenuItem> allMenuItems;
  final pw.Font ttfFontRegular;
  final pw.Font ttfFontBold;

  const BillLayoutWidget({
    Key? key,
    required this.orderData,
    this.businessName = "İşletmeniz",
    required this.allMenuItems,
    required this.ttfFontRegular,
    required this.ttfFontBold,
  }) : super(key: key);

  pw.TextStyle _textStyle({
    PdfColor color = PdfColors.black,
    double size = 10,
    required pw.Font baseFont,
  }) {
    return pw.TextStyle(font: baseFont, fontSize: size, color: color);
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(businessName, style: _textStyle(size: 16, baseFont: ttfFontBold)),
        pw.SizedBox(height: 5),
        pw.Text('Masa: ${orderData['table'] ?? 'Bilinmiyor'}', style: _textStyle(size: 12, baseFont: ttfFontRegular)),
        pw.Text(
          'Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.tryParse(orderData['created_at'] ?? DateTime.now().toIso8601String()) ?? DateTime.now())}',
          style: _textStyle(size: 9, color: PdfColors.grey600, baseFont: ttfFontRegular)),
        pw.Divider(height: 20, thickness: 1, color: PdfColors.grey400),
      ],
    );
  }

  pw.Widget _buildItemsTable() {
    final List<dynamic> items = orderData['order_items'] as List<dynamic>? ?? [];
    final List<pw.TableRow> tableRows = [];

    tableRows.add(pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('Ürün Adı', style: _textStyle(baseFont: ttfFontBold, size: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('Adet', style: _textStyle(baseFont: ttfFontBold, size: 9), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('Fiyat', style: _textStyle(baseFont: ttfFontBold, size: 9), textAlign: pw.TextAlign.right),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('Tutar', style: _textStyle(baseFont: ttfFontBold, size: 9), textAlign: pw.TextAlign.right),
        ),
      ],
    ));

    for (var itemData in items) {
      String productName = 'Bilinmeyen Ürün';
      String variantNameDisplay = '';
      int? menuItemIdActual;
      MenuItem? fullMenuItem;

      if (itemData['menu_item'] is Map && itemData['menu_item']['id'] != null) {
        menuItemIdActual = itemData['menu_item']['id'] as int?;
        productName = itemData['menu_item']['name'] ?? productName;
      } else if (itemData['menu_item'] is int) {
        menuItemIdActual = itemData['menu_item'] as int;
      }

      if (menuItemIdActual != null) {
        fullMenuItem = allMenuItems.firstWhereOrNull((m) => m.id == menuItemIdActual);
        if (fullMenuItem != null) {
          productName = fullMenuItem.name;
        } else {
          if (itemData['menu_item'] is Map && itemData['menu_item']['name'] != null) {
            productName = itemData['menu_item']['name'];
          }
          debugPrint("BillLayout: menuItemId $menuItemIdActual, allMenuItems içinde bulunamadı.");
        }
      } else if (itemData['menu_item'] is Map && itemData['menu_item']['name'] != null) {
        productName = itemData['menu_item']['name'];
      }

      if (itemData['variantId'] != null && fullMenuItem != null && fullMenuItem.variants != null) {
        final variantData = fullMenuItem.variants!.firstWhereOrNull((v) => v.id == itemData['variantId']);
        if (variantData != null) {
          variantNameDisplay = " (${variantData.name})";
        } else if (itemData['variant_name'] != null && itemData['variant_name'].toString().isNotEmpty) {
          variantNameDisplay = " (${itemData['variant_name']})";
        } else {
          variantNameDisplay = " (Varyant ID: ${itemData['variantId']})";
        }
      } else if (itemData['variant_name'] != null && itemData['variant_name'].toString().isNotEmpty) {
        variantNameDisplay = " (${itemData['variant_name']})";
      }

      final int quantity = itemData['quantity'] ?? 0;
      final double pricePerUnit = double.tryParse(itemData['price']?.toString() ?? '0.0') ?? 0.0;
      final double lineTotal = pricePerUnit * quantity;

      String extrasText = "";
      if (itemData['extras'] != null && (itemData['extras'] as List).isNotEmpty) {
        extrasText = "\n  Ekstralar: ";
        extrasText += (itemData['extras'] as List).map((e) {
          String extraName = "Ekstra";
          if (e is Map && e['variant_name'] != null) {
            extraName = e['variant_name'];
          } else if (e is Map && e['variant'] is int && fullMenuItem != null && fullMenuItem.variants != null) {
            final extraVariantData = fullMenuItem.variants!.firstWhereOrNull((v) => v.isExtra && v.id == e['variant']);
            if (extraVariantData != null) {
              extraName = extraVariantData.name;
            } else {
              extraName = "Ekstra ID: ${e['variant']}";
            }
          }
          return extraName;
        }).join(', ');
      }

      tableRows.add(pw.TableRow(
        children: [
          pw.Text('$productName$variantNameDisplay$extrasText', style: _textStyle(size: 8, baseFont: ttfFontRegular)),
          pw.Text(quantity.toString(), style: _textStyle(size: 8, baseFont: ttfFontRegular), textAlign: pw.TextAlign.center),
          pw.Text(pricePerUnit.toStringAsFixed(2), style: _textStyle(size: 8, baseFont: ttfFontRegular), textAlign: pw.TextAlign.right),
          pw.Text(lineTotal.toStringAsFixed(2), style: _textStyle(size: 8, baseFont: ttfFontRegular), textAlign: pw.TextAlign.right),
        ],
      ));
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3.0),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: tableRows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  pw.Widget _buildTotals() {
    double totalAmount = 0;
    final List<dynamic> items = orderData['order_items'] as List<dynamic>? ?? [];
    for (var item in items) {
      final int quantity = item['quantity'] ?? 0;
      final double price = double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
      totalAmount += price * quantity;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Divider(height: 20, thickness: 1, color: PdfColors.grey400),
        pw.Text('Genel Toplam: ${totalAmount.toStringAsFixed(2)} TL',
            style: _textStyle(size: 14, baseFont: ttfFontBold)),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text('Bizi tercih ettiğiniz için teşekkür ederiz!',
              style: _textStyle(size: 10, color: PdfColors.grey700, baseFont: ttfFontBold),
              textAlign: pw.TextAlign.center),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  static Future<pw.Document> generatePdf(
    PdfPageFormat format,
    dynamic orderData,
    String businessName,
    List<MenuItem> allMenuItems,
  ) async {
    final doc = pw.Document();

    final fontDataRegular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final fontDataBold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');

    final ttfRegular = pw.Font.ttf(fontDataRegular.buffer.asByteData());
    final ttfBold = pw.Font.ttf(fontDataBold.buffer.asByteData());

    final layout = BillLayoutWidget(
      orderData: orderData,
      businessName: businessName,
      allMenuItems: allMenuItems,
      ttfFontRegular: ttfRegular,
      ttfFontBold: ttfBold,
    );

    doc.addPage(pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(15),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            layout._buildHeader(),
            pw.SizedBox(height: 10),
            layout._buildItemsTable(),
            pw.SizedBox(height: 10),
            layout._buildTotals(),
          ],
        );
      },
    ));
    return doc;
  }

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
    double total = 0.0;

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
      PosColumn(textEncoded: utf8.encode('Ürün'), width: 6, styles: const PosStyles(bold: true)),
      PosColumn(textEncoded: utf8.encode('Adet'), width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(textEncoded: utf8.encode('Tutar'), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
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
      total += itemTotal;
      bytes += generator.row([
        PosColumn(textEncoded: utf8.encode(itemTitle), width: 6),
        PosColumn(text: item.quantity.toString(), width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: itemTotal.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();

    // Total
    bytes += generator.row([
      PosColumn(textEncoded: utf8.encode('TOPLAM'), width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: '${total.toStringAsFixed(2)} TL', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
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
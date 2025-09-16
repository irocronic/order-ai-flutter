// lib/services/qr_export_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

import 'api_service.dart';

class QrExportService {
  /// Tek masa için QR kodunu PDF olarak export et
  static Future<String> exportSingleTableQrPdf(Map<String, dynamic> table) async {
    final pdf = pw.Document();
    final robotoRegular = await PdfGoogleFonts.robotoRegular();
    final robotoBold = await PdfGoogleFonts.robotoBold();

    final String tableUuid = table['uuid']?.toString() ?? '';
    final String tableNumber = table['table_number'].toString();
    final uri = Uri.parse(ApiService.baseUrl.replaceAll('/api', ''));
    final String guestLink = tableUuid.isNotEmpty
        ? '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/guest/tables/$tableUuid/'
        : 'Link Yok';

    print('DEBUG: Masa $tableNumber için guestLink: $guestLink');

    pw.Widget qrWidget;
    if (tableUuid.isNotEmpty && guestLink.isNotEmpty && !guestLink.contains('Link Yok')) {
      try {
        qrWidget = pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: guestLink.trim(),
          width: 180,
          height: 180,
        );
        print('DEBUG: Masa $tableNumber için QR kodu başarıyla üretildi.');
      } catch (e) {
        print('ERROR: Masa $tableNumber için QR üretilemedi! guestLink: $guestLink');
        print('ERROR Detay: $e');
        qrWidget = pw.Text('QR Hata', style: pw.TextStyle(font: robotoRegular, fontSize: 12));
      }
    } else {
      qrWidget = pw.Text('QR Yok', style: pw.TextStyle(font: robotoRegular, fontSize: 12));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Masa $tableNumber',
                  style: pw.TextStyle(
                    font: robotoBold,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
                pw.SizedBox(height: 24),
                qrWidget,
                // pw.SizedBox(height: 24),
                // (Aşağıdaki satırı kaldırdık!)
                // pw.Text(
                //   guestLink,
                //   style: pw.TextStyle(
                //     font: robotoRegular,
                //     fontSize: 14,
                //     color: PdfColors.blue,
                //   ),
                // ),
              ],
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    final fileName = 'masa_${tableNumber}_qr_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    if (kIsWeb) {
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      return "Tarayıcıda indirme işlemi başlatıldı.";
    } else {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception("Depolama izni verilmedi.");
        }
      }

      final Directory? dir = await getDownloadsDirectory();
      if (dir == null) {
        throw Exception("İndirilenler klasörü bulunamadı.");
      }

      final String filePath = '${dir.path}/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception("Dosya açılamadı: ${result.message}");
      }

      return filePath;
    }
  }
}
// lib/services/report_exporter_service.dart

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file_plus/open_file_plus.dart';

/// Rapor verilerini Excel formatına dönüştürüp cihazda açan servis.
class ReportExporterService {
  
  /// Gelen satış verilerinden bir Excel raporu oluşturur ve dosyayı açar.
  static Future<void> createAndExportExcel(List<dynamic> salesData, String fileName) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Satış Raporu'];

    // DÜZELTME: Parametre adı '...Hex' olarak kaldı, ancak değer olarak String veya int yerine ExcelColor nesnesi verildi.
    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString("#FF1E88E5"), // Koyu Mavi
      fontColorHex: ExcelColor.fromHexString("#FFFFFFFF"),
      verticalAlign: VerticalAlign.Center,
      horizontalAlign: HorizontalAlign.Center,
    );
    
    List<CellValue> headers = [
      TextCellValue('Sipariş ID'),
      TextCellValue('Tarih'),
      TextCellValue('Saat'),
      TextCellValue('Sipariş Tipi'),
      TextCellValue('Masa/Müşteri'),
      TextCellValue('Ürün Adı'),
      TextCellValue('Varyant'),
      TextCellValue('Adet'),
      TextCellValue('Birim Fiyat'),
      TextCellValue('Toplam Tutar')
    ];
    sheetObject.appendRow(headers);

    for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = headerStyle;
    }

    // Verileri Satırlara Ekle
    double grandTotal = 0.0;
    for (var rowData in salesData) {
      final double lineTotal = double.tryParse(rowData['line_total']?.toString() ?? '0.0') ?? 0.0;
      final double unitPrice = double.tryParse(rowData['unit_price']?.toString() ?? '0.0') ?? 0.0;

      grandTotal += lineTotal;

      DateTime? createdAt;
      if (rowData['created_at'] != null) {
        createdAt = DateTime.tryParse(rowData['created_at'])?.toLocal();
      }

      sheetObject.appendRow([
        IntCellValue(rowData['order_id'] ?? 0),
        TextCellValue(createdAt != null ? DateFormat('dd.MM.yyyy').format(createdAt) : '-'),
        TextCellValue(createdAt != null ? DateFormat('HH:mm').format(createdAt) : '-'),
        TextCellValue(rowData['order_type'] == 'table' ? 'Masa' : 'Paket'),
        TextCellValue(rowData['order_type'] == 'table' ? (rowData['table_number']?.toString() ?? '-') : (rowData['customer_name'] ?? '-')),
        TextCellValue(rowData['item_name'] ?? ''),
        TextCellValue(rowData['variant_name'] ?? '-'),
        IntCellValue(rowData['quantity'] ?? 0),
        DoubleCellValue(unitPrice),
        DoubleCellValue(lineTotal),
      ]);
    }
    
    sheetObject.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('GENEL TOPLAM'),
      DoubleCellValue(grandTotal),
    ]);
    
    var fileBytes = excel.save();

    if (fileBytes != null) {
      await _saveAndOpenFile(fileBytes, fileName);
    }
  }

  /// Oluşturulan Excel dosyasını cihazda kaydeder ve açar.
  static Future<void> _saveAndOpenFile(List<int> fileBytes, String fileName) async {
    if (kIsWeb) {
      return;
    }
    
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    
    if (status.isGranted) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName.xlsx';
      
      final file = File(path);
      await file.writeAsBytes(fileBytes, flush: true);

      await OpenFile.open(path);
    } else {
        throw Exception("Dosya yazma izni verilmedi.");
    }
  }
}
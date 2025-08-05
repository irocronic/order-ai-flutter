// lib/models/printer_config.dart

import 'package:hive/hive.dart';

part 'printer_config.g.dart';

// Yazıcı tipleri (mutfak, kasa vb.)
enum PrinterType { kitchen, receipt }

@HiveType(typeId: 2) // Hive ID'sinin diğer modellerle çakışmadığından emin olun
class PrinterConfig extends HiveObject {
  @HiveField(0)
  late String id; // Benzersiz ID

  @HiveField(1)
  String name; // Kullanıcının verdiği isim (örn: Mutfak Yazıcısı)

  @HiveField(2)
  String ipAddress;

  @HiveField(3)
  int port;

  @HiveField(4)
  // Bu alanın ID'si 4, eskiden 5'ti. Sıralı olması daha iyi.
  String type; // 'kitchen' veya 'receipt'

  PrinterConfig({
    required this.name,
    required this.ipAddress,
    this.port = 9100,
    required this.type,
  }) {
    id = DateTime.now().millisecondsSinceEpoch.toString();
  }

  PrinterType get printerTypeEnum {
    return type == 'kitchen' ? PrinterType.kitchen : PrinterType.receipt;
  }
}
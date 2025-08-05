// lib/models/pager_device_model.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Bluetooth taraması sırasında keşfedilen cihazları temsil eder.
/// Bu model daha çok BluetoothService içinde anlık keşifler için kullanılır.
class PagerDevice {
  final BluetoothDevice device;
  final String name;
  final String id; // Cihazın MAC adresi veya Bluetooth remoteId'si

  PagerDevice({
    required this.device,
    required this.name,
    required this.id,
  });
}

/// Backend'de kayıtlı olan ve yönetilen Çağrı Cihazlarını temsil eder.
/// Bu model, PagerService aracılığıyla backend'den alınan veriler için kullanılır.
class PagerSystemDevice {
  final String id; // Backend'deki Pager modelinin primary key'i (genellikle int, ama string olarak da işlenebilir)
  final String deviceId; // Pager'ın benzersiz Bluetooth kimliği (MAC adresi vb.)
  String? name; // Kullanıcı tarafından verilen takma ad
  String status; // 'available', 'in_use', 'charging', 'low_battery', 'out_of_service'
  String statusDisplay; // Durumun okunabilir hali (örn: "Boşta")
  int? currentOrderId; // Eğer 'in_use' ise, bağlı olduğu Order ID'si
  DateTime? lastStatusUpdate; // Durumun son güncellenme zamanı
  String? notes; // Cihazla ilgili notlar
  final int businessId; // Hangi işletmeye ait olduğu

  // Opsiyonel: Eğer bu cihaz Bluetooth ile keşfedilmişse, anlık BluetoothDevice bilgisini tutabilir.
  // Bu, PagerManagementScreen'de hem sistemdeki kaydı hem de anlık BLE durumunu birleştirmek için kullanılabilir.
  BluetoothDevice? bleDevice;

  PagerSystemDevice({
    required this.id,
    required this.deviceId,
    this.name,
    required this.status,
    required this.statusDisplay,
    this.currentOrderId,
    this.lastStatusUpdate,
    this.notes,
    required this.businessId,
    this.bleDevice,
  });

  factory PagerSystemDevice.fromJson(Map<String, dynamic> json) {
    return PagerSystemDevice(
      id: json['id'].toString(), // Backend'den gelen ID (int veya string olabilir, string'e çeviriyoruz)
      deviceId: json['device_id'] ?? '',
      name: json['name'],
      status: json['status'] ?? 'unknown',
      statusDisplay: json['status_display'] ?? 'Bilinmiyor',
      currentOrderId: json['current_order'] as int?, // Django'dan null gelebilir
      lastStatusUpdate: json['last_status_update'] != null
          ? DateTime.tryParse(json['last_status_update'])
          : null,
      notes: json['notes'],
      businessId: json['business'] as int? ?? 0, // Backend'den int olarak geldiğini varsayıyoruz
    );
  }
}
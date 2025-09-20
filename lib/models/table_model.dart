// lib/models/table_model.dart

// YENİ IMPORT: Tip güvenliği sağlamak için oluşturulan arayüzü import ediyoruz.
import 'i_layout_item.dart';

// GÜNCELLENDİ: Sınıf tanımı, ILayoutItem arayüzünü uygulayacak şekilde değiştirildi.
class TableModel implements ILayoutItem {
  @override // ILayoutItem arayüzünden gelen 'id' alanını karşıladığını belirtir.
  final int id;
  int tableNumber;
  final String uuid;
  double? posX;
  double? posY;
  double rotation;
  final int? layoutId;

  TableModel({
    required this.id,
    required this.tableNumber,
    required this.uuid,
    this.posX,
    this.posY,
    this.rotation = 0.0,
    this.layoutId,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'],
      tableNumber: json['table_number'],
      uuid: json['uuid'] ?? '',
      posX: (json['pos_x'] as num?)?.toDouble(),
      posY: (json['pos_y'] as num?)?.toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      layoutId: json['layout'] as int?,
    );
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'id': id,
      'pos_x': posX,
      'pos_y': posY,
      'rotation': rotation,
    };
  }
}
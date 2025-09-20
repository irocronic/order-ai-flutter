// lib/models/layout_element.dart

import 'package:flutter/material.dart';
import 'shape_style.dart';
// YENİ IMPORT
import 'i_layout_item.dart';

enum LayoutElementType { text, shape }

// GÜNCELLENDİ: ILayoutItem arayüzünü uygular.
class LayoutElement implements ILayoutItem {
  @override
  int? id;
  final LayoutElementType type;
  Offset position;
  Size size;
  double rotation;
  Map<String, dynamic> styleProperties;

  LayoutElement({
    this.id,
    required this.type,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    required this.styleProperties,
  });

  // YENİ METOT: ElementEditor'da yapılan değişiklikleri uygulamak için
  // mevcut nesneyi kopyalayıp güncelleyen pratik bir metot.
  LayoutElement copyWith({
    int? id,
    LayoutElementType? type,
    Offset? position,
    Size? size,
    double? rotation,
    Map<String, dynamic>? styleProperties,
  }) {
    return LayoutElement(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      styleProperties: styleProperties ?? this.styleProperties,
    );
  }

  factory LayoutElement.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v, [double fallback = 0.0]) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      if (v is String) {
        return double.tryParse(v) ?? fallback;
      }
      return fallback;
    }

    final posX = parseDouble(json['pos_x'] ?? json['x'] ?? json['left'], 0.0);
    final posY = parseDouble(json['pos_y'] ?? json['y'] ?? json['top'], 0.0);
    final width = parseDouble(json['width'] ?? json['w'], 100.0);
    final height = parseDouble(json['height'] ?? json['h'], 30.0);
    final rotation = parseDouble(json['rotation'], 0.0);

    return LayoutElement(
      id: json['id'],
      type: LayoutElementType.values.firstWhere(
            (e) => e.name == (json['element_type'] as String? ?? json['elementType'] ?? 'text'),
        orElse: () => LayoutElementType.text,
      ),
      position: Offset(posX, posY),
      size: Size(width, height),
      rotation: rotation,
      styleProperties: Map<String, dynamic>.from(json['style_properties'] ?? json['styleProperties'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'element_type': type.name,
      'pos_x': position.dx,
      'pos_y': position.dy,
      'width': size.width,
      'height': size.height,
      'rotation': rotation,
      'style_properties': styleProperties,
    };
  }
  
  String get content => styleProperties['content'] ?? styleProperties['text'] ?? '';
  double get fontSize => (styleProperties['fontSize'] as num?)?.toDouble() ?? 14.0;
  Color get color => ShapeStyle.parseColor(styleProperties['color'] ?? styleProperties['fillColor'] ?? styleProperties['fill_color'] ?? Colors.black.value);
  bool get isBold => styleProperties['isBold'] ?? styleProperties['bold'] ?? false;
  ShapeStyle get shapeStyle => ShapeStyle.fromJson(Map<String, dynamic>.from(styleProperties));
}
// lib/models/shape_style.dart

import 'package:flutter/material.dart';

// YENİ EKLENDİ: Şekil türlerini ayırt etmek için enum.
enum ShapeType { rectangle, ellipse, line }

@immutable
class ShapeStyle {
  final ShapeType shapeType;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  const ShapeStyle({
    this.shapeType = ShapeType.rectangle,
    this.fillColor = Colors.blue,
    this.borderColor = Colors.black,
    this.borderWidth = 2.0,
  });

  ShapeStyle copyWith({
    ShapeType? shapeType,
    Color? fillColor,
    Color? borderColor,
    double? borderWidth,
  }) {
    return ShapeStyle(
      shapeType: shapeType ?? this.shapeType,
      fillColor: fillColor ?? this.fillColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }

  Map<String, dynamic> toJson() => {
        'shapeType': shapeType.name,
        'fillColor': fillColor.value,
        'borderColor': borderColor.value,
        'borderWidth': borderWidth,
      };

  // Yardımcı: JSON'dan gelen renk değeri hem int hem de hex string olabileceği için
  // esnek parse yapan fonksiyon.
  static Color parseColor(dynamic jsonColor) {
    try {
      if (jsonColor == null) return Colors.blue;
      if (jsonColor is int) return Color(jsonColor);
      if (jsonColor is String) {
        // Örn: "#RRGGBB" veya "RRGGBB" veya "#AARRGGBB"
        String s = jsonColor.trim();
        if (s.startsWith('#')) s = s.substring(1);
        // Eğer alpha yoksa FF ekle
        if (s.length == 6) s = 'FF' + s;
        return Color(int.parse(s, radix: 16));
      }
    } catch (_) {
      // fallback
    }
    return Colors.blue;
  }

  factory ShapeStyle.fromJson(Map<String, dynamic> json) {
    return ShapeStyle(
      shapeType: json.containsKey('shapeType')
          ? ShapeType.values.firstWhere(
              (e) => e.name == (json['shapeType'] as String? ?? 'rectangle'),
              orElse: () => ShapeType.rectangle,
            )
          : ShapeType.rectangle,
      fillColor: parseColor(json['fillColor'] ?? json['fill_color']),
      borderColor: parseColor(json['borderColor'] ?? json['border_color']),
      borderWidth: (json['borderWidth'] ?? json['border_width'] ?? 2.0) is num
          ? (json['borderWidth'] ?? json['border_width'] ?? 2.0).toDouble()
          : 2.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShapeStyle &&
          runtimeType == other.runtimeType &&
          shapeType == other.shapeType &&
          fillColor == other.fillColor &&
          borderColor == other.borderColor &&
          borderWidth == other.borderWidth;

  @override
  int get hashCode =>
      shapeType.hashCode ^
      fillColor.hashCode ^
      borderColor.hashCode ^
      borderWidth.hashCode;
}
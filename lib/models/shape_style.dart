// YENİ DOSYA: lib/models/shape_style.dart

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

  factory ShapeStyle.fromJson(Map<String, dynamic> json) {
    return ShapeStyle(
      shapeType: ShapeType.values.byName(json['shapeType'] ?? 'rectangle'),
      fillColor: Color(json['fillColor'] ?? Colors.blue.value),
      borderColor: Color(json['borderColor'] ?? Colors.black.value),
      borderWidth: json['borderWidth'] ?? 2.0,
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
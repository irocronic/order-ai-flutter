// lib/models/business_card_model.dart

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'card_icon_enum.dart';
import 'shape_style.dart';

enum CardElementType { text, image, icon, qrCode, group, shape }

enum GradientType { linear, radial }

@immutable
class CardElement {
  final String id;
  final CardElementType type;
  final String content;
  final Uint8List? imageData;
  final Offset position;
  final Size size;
  final TextStyle style;
  final ShapeStyle? shapeStyle;
  final TextAlign textAlign;
  final double rotation;
  final double opacity;
  final String? groupId;
  final List<CardElement>? children;

  const CardElement({
    required this.id,
    required this.type,
    required this.content,
    this.imageData,
    required this.position,
    required this.size,
    required this.style,
    this.shapeStyle,
    this.textAlign = TextAlign.left,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.groupId,
    this.children,
  });

  CardElement copyWith({
    String? id,
    CardElementType? type,
    String? content,
    Uint8List? imageData,
    Offset? position,
    Size? size,
    TextStyle? style,
    ShapeStyle? shapeStyle,
    TextAlign? textAlign,
    double? rotation,
    double? opacity,
    String? groupId,
    List<CardElement>? children,
  }) {
    return CardElement(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      imageData: imageData ?? this.imageData,
      position: position ?? this.position,
      size: size ?? this.size,
      style: style ?? this.style,
      shapeStyle: shapeStyle ?? this.shapeStyle,
      textAlign: textAlign ?? this.textAlign,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      groupId: groupId ?? this.groupId,
      children: children ?? this.children,
    );
  }

  Map<String, dynamic> toJson() {
    final List<Shadow>? shadows = style.shadows;
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'imageData': imageData != null ? base64Encode(imageData!) : null,
      'position': {'dx': position.dx, 'dy': position.dy},
      'size': {'width': size.width, 'height': size.height},
      'style': {
        'color': style.color?.value,
        'fontSize': style.fontSize,
        'fontWeight': style.fontWeight?.toString(),
        'fontStyle': style.fontStyle?.toString(),
        'fontFamily': style.fontFamily,
        'letterSpacing': style.letterSpacing,
        'height': style.height,
        'shadows': shadows?.map((s) => {
          'color': s.color.value,
          'offsetX': s.offset.dx,
          'offsetY': s.offset.dy,
          'blurRadius': s.blurRadius,
        }).toList(),
      },
      'shapeStyle': shapeStyle?.toJson(),
      'textAlign': textAlign.name,
      'rotation': rotation,
      'opacity': opacity,
      'groupId': groupId,
      'children': children?.map((e) => e.toJson()).toList(),
    };
  }

  // GÜNCELLEME BAŞLANGICI: JSON'dan CardElement oluşturma metodu daha güvenli hale getirildi.
  factory CardElement.fromJson(Map<String, dynamic> json) {
    FontWeight? fontWeight;
    FontStyle? fontStyle;
    List<Shadow>? shadows;
    TextStyle textStyle;

    // 'style' anahtarının var olup olmadığını ve null olup olmadığını kontrol ediyoruz.
    final styleMap = json['style'] as Map<String, dynamic>?;

    if (styleMap != null) {
      // styleMap null değilse, içindeki değerleri güvenle okuyabiliriz.
      if (styleMap['fontWeight'] == FontWeight.bold.toString()) {
        fontWeight = FontWeight.bold;
      }

      if (styleMap['fontStyle'] == FontStyle.italic.toString()) {
        fontStyle = FontStyle.italic;
      }

      if (styleMap['shadows'] != null) {
        shadows = (styleMap['shadows'] as List).map((s) => Shadow(
          color: Color(s['color']),
          offset: Offset(s['offsetX'], s['offsetY']),
          blurRadius: s['blurRadius'],
        )).toList();
      }
      
      textStyle = TextStyle(
        color: styleMap['color'] != null ? Color(styleMap['color']) : Colors.black,
        fontSize: styleMap['fontSize'],
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        fontFamily: styleMap['fontFamily'],
        letterSpacing: styleMap['letterSpacing'],
        height: styleMap['height'],
        shadows: shadows,
      );
    } else {
      // Eğer JSON içinde 'style' objesi yoksa (örneğin şekil elemanları için),
      // varsayılan boş bir TextStyle oluşturuyoruz.
      textStyle = const TextStyle();
    }
    
    return CardElement(
      id: json['id'],
      type: CardElementType.values.byName(json['type']),
      content: json['content'],
      imageData: json['imageData'] != null ? base64Decode(json['imageData']) : null,
      position: Offset(json['position']['dx'], json['position']['dy']),
      size: Size(json['size']['width'], json['size']['height']),
      style: textStyle, // Güvenli bir şekilde oluşturulan TextStyle'ı atıyoruz.
      shapeStyle: json['shapeStyle'] != null ? ShapeStyle.fromJson(json['shapeStyle']) : null,
      textAlign: TextAlign.values.byName(json['textAlign'] ?? 'left'),
      rotation: json['rotation'] ?? 0.0,
      opacity: json['opacity'] ?? 1.0,
      groupId: json['groupId'],
      children: json['children'] != null
          ? List<CardElement>.from(json['children'].map((x) => CardElement.fromJson(x)))
          : null,
    );
  }
  // GÜNCELLEME SONU

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is CardElement &&
        other.id == id &&
        other.type == type &&
        other.content == content &&
        other.position == position &&
        other.size == size &&
        other.style == style &&
        other.shapeStyle == shapeStyle &&
        other.textAlign == textAlign &&
        other.rotation == rotation &&
        other.opacity == opacity &&
        other.groupId == groupId &&
        listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(id, type, content, position, size, style, shapeStyle, textAlign, rotation, opacity, groupId, children);
}

@immutable
class BusinessCardModel {
  final Color gradientStartColor;
  final Color? gradientEndColor;
  final GradientType? gradientType;

  final List<CardElement> elements;
  final Size dimensions;
  const BusinessCardModel({
    required this.gradientStartColor,
    this.gradientEndColor,
    this.gradientType,
    required this.elements,
    this.dimensions = const Size(350, 200),
  });
  BusinessCardModel copyWith({
    Color? gradientStartColor,
    Color? gradientEndColor,
    GradientType? gradientType,
    List<CardElement>? elements,
    Size? dimensions,
  }) {
    return BusinessCardModel(
      gradientStartColor: gradientStartColor ?? this.gradientStartColor,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      gradientType: gradientType ?? this.gradientType,
      elements: elements ?? this.elements,
      dimensions: dimensions ?? this.dimensions,
    );
  }

  factory BusinessCardModel.defaultCard() {
    return BusinessCardModel(
      gradientStartColor: Colors.white,
      elements: [
        CardElement(
          id: UniqueKey().toString(),
          type: CardElementType.text,
          content: 'Ad Soyad',
          position: const Offset(20, 30),
          size: const Size(200, 40),
           style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Roboto'),
        ),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'gradientStartColor': gradientStartColor.value,
        'gradientEndColor': gradientEndColor?.value,
        'gradientType': gradientType?.name,
        'elements': elements.map((e) => e.toJson()).toList(),
        'dimensions': {'width': dimensions.width, 'height': dimensions.height},
      };
      
  factory BusinessCardModel.fromJson(Map<String, dynamic> json) {
    return BusinessCardModel(
      gradientStartColor: Color(json['gradientStartColor'] ?? Colors.white.value),
      gradientEndColor: json['gradientEndColor'] != null ? Color(json['gradientEndColor']) : null,
      gradientType: json['gradientType'] != null ? GradientType.values.byName(json['gradientType']) : null,
      elements: List<CardElement>.from(
          json['elements'].map((x) => CardElement.fromJson(x))),
      dimensions:
          Size(json['dimensions']['width'], json['dimensions']['height']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is BusinessCardModel &&
        other.gradientStartColor == gradientStartColor &&
        other.gradientEndColor == gradientEndColor &&
        other.gradientType == gradientType &&
        other.dimensions == dimensions &&
        listEquals(other.elements, elements);
  }

  @override
  int get hashCode => Object.hash(gradientStartColor, gradientEndColor, gradientType, dimensions, elements);
}
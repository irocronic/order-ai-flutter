// lib/models/business_card_model.dart

import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'card_icon_enum.dart';
import 'package:collection/collection.dart'; // Deep equality için

// GÜNCELLEME: Yeni eleman tipleri eklendi (qrCode, group).
enum CardElementType { text, image, icon, qrCode, group }

// GÜNCELLEME: Arka plan gradyan tipleri için.
enum GradientType { linear, radial }

// Kartvizit üzerindeki her bir elemanı temsil eden, "immutable" (değişmez) sınıf
@immutable
class CardElement {
  final String id;
  final CardElementType type;
  // Metin içeriği, ikon için CardIcon.name, QR kod için veri, grup için 'Grup'
  final String content;
  final Uint8List? imageData;
  final Offset position;
  final Size size;
  final TextStyle style;
  final TextAlign textAlign;
  final double rotation; // Döndürme açısı (radyan cinsinden)

  // YENİ: Opaklık
  final double opacity;
  // YENİ: Gruplama için
  final String? groupId;
  // YENİ: Grup elemanları için alt elemanlar listesi
  final List<CardElement>? children;

  const CardElement({
    required this.id,
    required this.type,
    required this.content,
    this.imageData,
    required this.position,
    required this.size,
    required this.style,
    this.textAlign = TextAlign.left,
    this.rotation = 0.0,
    this.opacity = 1.0, // Varsayılan opaklık
    this.groupId,
    this.children,
  });

  // Değişiklikler için kopyalama metodu
  CardElement copyWith({
    String? id,
    CardElementType? type,
    String? content,
    Uint8List? imageData,
    Offset? position,
    Size? size,
    TextStyle? style,
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
      textAlign: textAlign ?? this.textAlign,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      groupId: groupId ?? this.groupId,
      children: children ?? this.children,
    );
  }

  // JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    // GÜNCELLEME: Yeni özellikler eklendi.
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
        'letterSpacing': style.letterSpacing, // YENİ
        'height': style.height, // YENİ
        'shadows': shadows?.map((s) => { // YENİ
          'color': s.color.value,
          'offsetX': s.offset.dx,
          'offsetY': s.offset.dy,
          'blurRadius': s.blurRadius,
        }).toList(),
      },
      'textAlign': textAlign.name,
      'rotation': rotation,
      'opacity': opacity, // YENİ
      'groupId': groupId, // YENİ
      'children': children?.map((e) => e.toJson()).toList(), // YENİ
    };
  }

  // JSON'dan oluşturma
  factory CardElement.fromJson(Map<String, dynamic> json) {
    // GÜNCELLEME: Yeni özellikler eklendi.
    FontWeight? fontWeight;
    if (json['style']['fontWeight'] == FontWeight.bold.toString()) {
      fontWeight = FontWeight.bold;
    }

    FontStyle? fontStyle;
    if (json['style']['fontStyle'] == FontStyle.italic.toString()) {
      fontStyle = FontStyle.italic;
    }

    List<Shadow>? shadows;
    if (json['style']['shadows'] != null) {
      shadows = (json['style']['shadows'] as List).map((s) => Shadow(
        color: Color(s['color']),
        offset: Offset(s['offsetX'], s['offsetY']),
        blurRadius: s['blurRadius'],
      )).toList();
    }
    
    return CardElement(
      id: json['id'],
      type: CardElementType.values.byName(json['type']),
      content: json['content'],
      imageData:
          json['imageData'] != null ? base64Decode(json['imageData']) : null,
      position: Offset(json['position']['dx'], json['position']['dy']),
      size: Size(json['size']['width'], json['size']['height']),
      style: TextStyle(
        color: json['style']['color'] != null
            ? Color(json['style']['color'])
            : Colors.black,
        fontSize: json['style']['fontSize'],
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        fontFamily: json['style']['fontFamily'],
        letterSpacing: json['style']['letterSpacing'], // YENİ
        height: json['style']['height'], // YENİ
        shadows: shadows, // YENİ
      ),
      textAlign: TextAlign.values.byName(json['textAlign'] ?? 'left'),
      rotation: json['rotation'] ?? 0.0,
      opacity: json['opacity'] ?? 1.0, // YENİ
      groupId: json['groupId'], // YENİ
      children: json['children'] != null // YENİ
          ? List<CardElement>.from(json['children'].map((x) => CardElement.fromJson(x)))
          : null,
    );
  }

  // Undo/Redo için derinlemesine karşılaştırma
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
        other.textAlign == textAlign &&
        other.rotation == rotation &&
        other.opacity == opacity &&
        other.groupId == groupId &&
        listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(id, type, content, position, size, style, textAlign, rotation, opacity, groupId, children);
}

// Kartvizitin genel yapısını ve tüm elemanlarını içeren ana "immutable" model
@immutable
class BusinessCardModel {
  // GÜNCELLEME: Gradyan desteği için
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

  // Değişiklikler için kopyalama metodu
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

  // Varsayılan bir kartvizit şablonu
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

  // JSON'a dönüştürme
  Map<String, dynamic> toJson() => {
        // GÜNCELLEME: Gradyan desteği için
        'gradientStartColor': gradientStartColor.value,
        'gradientEndColor': gradientEndColor?.value,
        'gradientType': gradientType?.name,
        'elements': elements.map((e) => e.toJson()).toList(),
        'dimensions': {'width': dimensions.width, 'height': dimensions.height},
      };

  // JSON'dan oluşturma
  factory BusinessCardModel.fromJson(Map<String, dynamic> json) {
    return BusinessCardModel(
      // GÜNCELLEME: Gradyan desteği için
      gradientStartColor: Color(json['gradientStartColor'] ?? Colors.white.value),
      gradientEndColor: json['gradientEndColor'] != null ? Color(json['gradientEndColor']) : null,
      gradientType: json['gradientType'] != null ? GradientType.values.byName(json['gradientType']) : null,
      elements: List<CardElement>.from(
          json['elements'].map((x) => CardElement.fromJson(x))),
      dimensions:
          Size(json['dimensions']['width'], json['dimensions']['height']),
    );
  }

  // Undo/Redo için derinlemesine karşılaştırma
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
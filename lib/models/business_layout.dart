// lib/models/business_layout.dart

import 'table_model.dart';
import 'layout_element.dart'; // YENİ IMPORT

class BusinessLayout {
  final int id;
  final double width;
  final double height;
  final String? backgroundImageUrl;
  final List<TableModel> tables;
  final List<LayoutElement> elements; // YENİ ALAN

  BusinessLayout({
    required this.id,
    required this.width,
    required this.height,
    this.backgroundImageUrl,
    required this.tables,
    required this.elements, // YENİ ALAN
  });

  factory BusinessLayout.fromJson(Map<String, dynamic> json) {
    return BusinessLayout(
      id: json['id'],
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      backgroundImageUrl: json['background_image_url'],
      tables: (json['tables_on_layout'] as List<dynamic>?)
              ?.map((tableJson) => TableModel.fromJson(tableJson))
              .toList() ??
          [],
      // YENİ PARSING LOGIC
      elements: (json['elements'] as List<dynamic>?)
              ?.map((elementJson) => LayoutElement.fromJson(elementJson))
              .toList() ??
          [],
    );
  }
}

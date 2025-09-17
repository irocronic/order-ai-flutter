// YENİ DOSYA: lib/widgets/designer/shape_painter.dart

import 'package:flutter/material.dart';
import '../../models/shape_style.dart';

class ShapePainter extends CustomPainter {
  final ShapeStyle style;

  ShapePainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = style.fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = style.borderColor
      ..strokeWidth = style.borderWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    switch (style.shapeType) {
      case ShapeType.rectangle:
        if (style.fillColor.opacity > 0) {
          canvas.drawRect(rect, fillPaint);
        }
        if (style.borderWidth > 0) {
          canvas.drawRect(rect, borderPaint);
        }
        break;
      case ShapeType.ellipse:
        if (style.fillColor.opacity > 0) {
          canvas.drawOval(rect, fillPaint);
        }
        if (style.borderWidth > 0) {
          canvas.drawOval(rect, borderPaint);
        }
        break;
      case ShapeType.line:
        // Çizgi için dolgu olmaz, sadece kenarlık rengi kullanılır.
        final linePaint = Paint()
          ..color = style.borderColor
          ..strokeWidth = style.borderWidth
          ..style = PaintingStyle.stroke;
        // Çizgi her zaman yatay olarak çizilir, döndürme ile açısı ayarlanır.
        canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), linePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
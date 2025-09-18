// lib/widgets/table_layout/element_renderer.dart

import 'package:flutter/material.dart';
import '../../models/layout_element.dart';
import '../../models/shape_style.dart';
import 'dart:math' as math;

class ElementRenderer extends StatelessWidget {
  final LayoutElement element;
  final bool isSelected;

  const ElementRenderer({
    Key? key,
    required this.element,
    required this.isSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child;

    // Elemanın tipine göre uygun widget'ı oluştur
    switch (element.type) {
      case LayoutElementType.text:
        child = Text(
          element.content,
          style: TextStyle(
            fontSize: element.fontSize,
            color: element.color,
            fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
          ),
        );
        break;
      case LayoutElementType.shape:
        child = CustomPaint(
          size: element.size,
          painter: ShapePainter(style: element.shapeStyle),
        );
        break;
    }

    // Seçim çerçevesi
    return Container(
      width: element.size.width,
      height: element.size.height,
      decoration: isSelected
          ? BoxDecoration(
              border: Border.all(color: Colors.blueAccent, width: 2),
            )
          : null,
      child: Transform.rotate(
        angle: element.rotation * (math.pi / 180),
        child: child,
      ),
    );
  }
}

// Şekilleri çizmek için kullanılan yardımcı sınıf
class ShapePainter extends CustomPainter {
  final ShapeStyle style;
  ShapePainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = style.fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = style.borderColor
      ..strokeWidth = style.borderWidth
      ..style = PaintingStyle.stroke;

    switch (style.shapeType) {
      case ShapeType.rectangle:
        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        canvas.drawRect(rect, paint);
        if (style.borderWidth > 0) {
          canvas.drawRect(rect, borderPaint);
        }
        break;
      case ShapeType.ellipse:
        final rect = Rect.fromLTWH(0, 0, size.width, size.height);
        canvas.drawOval(rect, paint);
        if (style.borderWidth > 0) {
          canvas.drawOval(rect, borderPaint);
        }
        break;
      case ShapeType.line:
        // Çizgi için borderPaint'i fill gibi kullanırız
        final linePaint = Paint()
          ..color = style.borderColor
          ..strokeWidth = size.height // Kalınlığı size'ın yüksekliğinden alır
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), linePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
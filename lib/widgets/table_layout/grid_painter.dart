// lib/widgets/table_layout/grid_painter.dart

import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final double gridSpacing;
  final Color gridColor;

  GridPainter({
    required this.gridSpacing,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.fill;

    // Tuvalin genişliği ve yüksekliği boyunca ızgara noktalarını çiz
    for (double i = 0; i < size.width; i += gridSpacing) {
      for (double j = 0; j < size.height; j += gridSpacing) {
        // Her bir ızgara kesişimine küçük bir daire çiziyoruz
        canvas.drawCircle(Offset(i, j), 1.0, paint);
      }
    }
  }

  // Izgara aralığı veya rengi değişmediği sürece yeniden çizim yapma (performans için)
  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridSpacing != gridSpacing ||
        oldDelegate.gridColor != gridColor;
  }
}
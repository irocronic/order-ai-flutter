// lib/widgets/table_layout/table_widget.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/table_model.dart';

class TableWidget extends StatelessWidget {
  final TableModel table;
  final bool isSelected;

  const TableWidget({
    Key? key,
    required this.table,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Masanın boyutlarını burada sabit olarak tanımlayabiliriz.
    const double tableWidth = 80.0;
    const double tableHeight = 50.0;

    return Transform.rotate(
      angle: table.rotation * math.pi / 180, // Dereceyi radyana çevir
      child: Container(
        width: tableWidth,
        height: tableHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.shade200.withOpacity(0.8)
              : Colors.grey.shade200.withOpacity(0.9),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade500,
            width: isSelected ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Center(
          child: Text(
            table.tableNumber.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: isSelected ? Colors.blue.shade900 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
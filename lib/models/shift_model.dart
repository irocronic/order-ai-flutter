// lib/models/shift_model.dart

import 'package:flutter/material.dart';

class Shift {
  final int id;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;

  Shift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.color,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    // "18:00:00" formatındaki string'i TimeOfDay'e çevirir.
    TimeOfDay _timeFromString(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    // Renk kodunu Color objesine çevirir.
    Color _colorFromHex(String hexColor) {
      hexColor = hexColor.toUpperCase().replaceAll("#", "");
      if (hexColor.length == 6) {
        hexColor = "FF" + hexColor;
      }
      return Color(int.parse(hexColor, radix: 16));
    }

    return Shift(
      id: json['id'],
      name: json['name'] ?? 'Bilinmeyen Vardiya',
      startTime: _timeFromString(json['start_time'] ?? '00:00:00'),
      endTime: _timeFromString(json['end_time'] ?? '00:00:00'),
      color: _colorFromHex(json['color'] ?? '#3788D8'),
    );
  }
}
// lib/models/scheduled_shift_model.dart

import 'package:flutter/material.dart'; // <<< HATA BURADAYDI, DÜZELTİLDİ
import './shift_model.dart';
import '../services/user_session.dart';

class ScheduledShift {
  final int id;
  final int staffId;
  final String staffUsername;
  final DateTime date;
  final Shift shift;
  final String? endDateTimeUtc;

  ScheduledShift({
    required this.id,
    required this.staffId,
    required this.staffUsername,
    required this.date,
    required this.shift,
    this.endDateTimeUtc,
  });

  // Gelen farklı JSON yapılarını işlemek için güncellenmiş factory metodu
  factory ScheduledShift.fromJson(Map<String, dynamic> json) {
    return ScheduledShift(
      id: json['id'],
      staffId: json['staff_details']?['id'] ?? json['staff'] ?? UserSession.userId ?? 0,
      staffUsername: json['staff_details']?['username'] ?? json['staff_username'] ?? UserSession.username,
      date: DateTime.parse(json['date']),
      // Hem 'shift_details' (iç içe yapı) hem de düz yapı desteği
      shift: json.containsKey('shift_details')
          ? Shift.fromJson(json['shift_details'])
          : Shift( // Düz yapıdan geçici Shift nesnesi oluştur
              id: json['shift_id'] ?? 0,
              name: json['shift_name'] ?? 'Vardiya',
              startTime: TimeOfDay(hour: int.parse(json['start_time'].split(':')[0]), minute: int.parse(json['start_time'].split(':')[1])),
              endTime: TimeOfDay(hour: int.parse(json['end_time'].split(':')[0]), minute: int.parse(json['end_time'].split(':')[1])),
              color: Colors.transparent
            ),
      endDateTimeUtc: json['end_datetime_utc'],
    );
  }
}
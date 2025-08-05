import './shift_model.dart';

class ScheduledShift {
  final int id;
  final int staffId;
  final String staffUsername;
  final DateTime date;
  final Shift shift;

  ScheduledShift({
    required this.id,
    required this.staffId,
    required this.staffUsername,
    required this.date,
    required this.shift,
  });

  factory ScheduledShift.fromJson(Map<String, dynamic> json) {
    return ScheduledShift(
      id: json['id'],
      staffId: json['staff_details']?['id'] ?? 0,
      staffUsername: json['staff_details']?['username'] ?? 'Bilinmiyor',
      date: DateTime.parse(json['date']),
      shift: Shift.fromJson(json['shift_details']),
    );
  }
}
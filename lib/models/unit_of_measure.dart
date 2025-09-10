// lib/models/unit_of_measure.dart

class UnitOfMeasure {
  final int id;
  final String name;
  final String abbreviation;

  UnitOfMeasure({
    required this.id,
    required this.name,
    required this.abbreviation,
  });

  factory UnitOfMeasure.fromJson(Map<String, dynamic> json) {
    return UnitOfMeasure(
      id: json['id'],
      name: json['name'],
      abbreviation: json['abbreviation'],
    );
  }
}
// lib/models/supplier.dart

class Supplier {
  final int id;
  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;

  Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Bilinmeyen Tedarikçi',
      contactPerson: json['contact_person'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact_person': contactPerson,
      'email': email,
      'phone': phone,
      'address': address,
    };
  }
}
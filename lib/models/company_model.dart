import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final double debt; // Borç (pozitif)
  final double receivable; // Alacak (pozitif)
  final String? photoUrl; // Fotoğraf URL'i
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanyModel({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    required this.debt,
    required this.receivable,
    this.photoUrl,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompanyModel.fromMap(Map<String, dynamic> map, String id) {
    return CompanyModel(
      id: id,
      name: map['name'] ?? '',
      contactPerson: map['contact_person'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      debt: (map['debt'] as num?)?.toDouble() ?? 0.0,
      receivable: (map['receivable'] as num?)?.toDouble() ?? 0.0,
      photoUrl: map['photo_url'] as String?,
      notes: map['notes'] ?? '',
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contact_person': contactPerson,
      'phone': phone,
      'email': email,
      'debt': debt,
      'receivable': receivable,
      'photo_url': photoUrl,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  CompanyModel copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    double? debt,
    double? receivable,
    String? photoUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      debt: debt ?? this.debt,
      receivable: receivable ?? this.receivable,
      photoUrl: photoUrl ?? this.photoUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

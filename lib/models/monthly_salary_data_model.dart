import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlySalaryDataModel {
  final String id;
  final String userId;
  final DateTime month; // Ayın ilk günü
  final double remainingNetSalary; // Kalan net maaş (admin tarafından düzenlenebilir)
  final double totalAdvances; // Toplam avanslar (admin tarafından düzenlenebilir)
  final String? adminNotes; // Admin notları
  final DateTime createdAt;
  final DateTime updatedAt;

  MonthlySalaryDataModel({
    required this.id,
    required this.userId,
    required this.month,
    required this.remainingNetSalary,
    required this.totalAdvances,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MonthlySalaryDataModel.fromMap(Map<String, dynamic> map, String id) {
    return MonthlySalaryDataModel(
      id: id,
      userId: map['user_id'] ?? '',
      month: (map['month'] as Timestamp).toDate(),
      remainingNetSalary: (map['remaining_net_salary'] ?? 0.0).toDouble(),
      totalAdvances: (map['total_advances'] ?? 0.0).toDouble(),
      adminNotes: map['admin_notes'],
      createdAt: (map['created_at'] as Timestamp).toDate(),
      updatedAt: (map['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'month': Timestamp.fromDate(month),
      'remaining_net_salary': remainingNetSalary,
      'total_advances': totalAdvances,
      'admin_notes': adminNotes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  MonthlySalaryDataModel copyWith({
    String? id,
    String? userId,
    DateTime? month,
    double? remainingNetSalary,
    double? totalAdvances,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlySalaryDataModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      month: month ?? this.month,
      remainingNetSalary: remainingNetSalary ?? this.remainingNetSalary,
      totalAdvances: totalAdvances ?? this.totalAdvances,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

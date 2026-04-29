import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryPaymentModel {
  final String id;
  final String userId;
  final DateTime month; // Ödeme yapılan ayın ilk günü
  final double paidAmount; // Ödenen tutar
  final DateTime paidDate; // Ödeme tarihi
  final String? notes; // Notlar
  final DateTime createdAt; // Kayıt oluşturulma tarihi

  SalaryPaymentModel({
    required this.id,
    required this.userId,
    required this.month,
    required this.paidAmount,
    required this.paidDate,
    this.notes,
    required this.createdAt,
  });

  factory SalaryPaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return SalaryPaymentModel(
      id: id,
      userId: map['user_id'] ?? '',
      month: (map['month'] as Timestamp).toDate(),
      paidAmount: (map['paid_amount'] ?? 0.0).toDouble(),
      paidDate: (map['paid_date'] as Timestamp).toDate(),
      notes: map['notes'],
      createdAt: (map['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'month': Timestamp.fromDate(month),
      'paid_amount': paidAmount,
      'paid_date': Timestamp.fromDate(paidDate),
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  SalaryPaymentModel copyWith({
    String? id,
    String? userId,
    DateTime? month,
    double? paidAmount,
    DateTime? paidDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return SalaryPaymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      month: month ?? this.month,
      paidAmount: paidAmount ?? this.paidAmount,
      paidDate: paidDate ?? this.paidDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

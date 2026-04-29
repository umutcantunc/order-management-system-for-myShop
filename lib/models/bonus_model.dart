import 'package:cloud_firestore/cloud_firestore.dart';

class BonusModel {
  final String id;
  final String userId;
  final double amount;
  final String? notes;
  final DateTime month; // Hangi ay için prim (sadece yıl ve ay önemli)
  final DateTime createdAt;
  final DateTime updatedAt;

  BonusModel({
    required this.id,
    required this.userId,
    required this.amount,
    this.notes,
    required this.month,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BonusModel.fromMap(Map<String, dynamic> map, String id) {
    return BonusModel(
      id: id,
      userId: map['user_id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      month: map['month'] != null
          ? (map['month'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'amount': amount,
      'notes': notes,
      'month': Timestamp.fromDate(month),
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  BonusModel copyWith({
    String? id,
    String? userId,
    double? amount,
    String? notes,
    DateTime? month,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BonusModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      month: month ?? this.month,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'payment', 'advance', 'bonus'
  final DateTime date;
  final String description;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.date,
    required this.description,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      userId: map['user_id'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: map['type'] ?? 'payment',
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'amount': amount,
      'type': type,
      'date': Timestamp.fromDate(date),
      'description': description,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerStatisticsModel {
  final String id;
  final DateTime date;
  final int customerCount;
  final double cashAmount;
  final double cardAmount;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerStatisticsModel({
    required this.id,
    required this.date,
    required this.customerCount,
    required this.cashAmount,
    required this.cardAmount,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerStatisticsModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerStatisticsModel(
      id: id,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      customerCount: map['customer_count'] ?? 0,
      cashAmount: (map['cash_amount'] as num?)?.toDouble() ?? 0.0,
      cardAmount: (map['card_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'customer_count': customerCount,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      'total_amount': totalAmount,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  CustomerStatisticsModel copyWith({
    String? id,
    DateTime? date,
    int? customerCount,
    double? cashAmount,
    double? cardAmount,
    double? totalAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerStatisticsModel(
      id: id ?? this.id,
      date: date ?? this.date,
      customerCount: customerCount ?? this.customerCount,
      cashAmount: cashAmount ?? this.cashAmount,
      cardAmount: cardAmount ?? this.cardAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

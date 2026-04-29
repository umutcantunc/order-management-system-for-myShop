import 'package:cloud_firestore/cloud_firestore.dart';

class DailySalesModel {
  final String id;
  final DateTime date;
  final double amount; // Toplam tutar (cashAmount + cardAmount)
  final double cashAmount; // Nakit tutar
  final double cardAmount; // Kart tutar
  final String? notes;
  final String? customerName; // Müşteri adı (opsiyonel)
  final String? orderNumber; // Sipariş numarası (opsiyonel)

  DailySalesModel({
    required this.id,
    required this.date,
    required this.amount,
    required this.cashAmount,
    required this.cardAmount,
    this.notes,
    this.customerName,
    this.orderNumber,
  });

  factory DailySalesModel.fromMap(Map<String, dynamic> map, String id) {
    final cashAmount = (map['cash_amount'] as num?)?.toDouble() ?? 0.0;
    final cardAmount = (map['card_amount'] as num?)?.toDouble() ?? 0.0;
    // Eğer eski verilerde amount varsa ama cash_amount ve card_amount yoksa, amount'u cashAmount olarak kabul et
    final amount = (map['amount'] as num?)?.toDouble() ?? (cashAmount + cardAmount);
    
    return DailySalesModel(
      id: id,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount: amount,
      cashAmount: cashAmount,
      cardAmount: cardAmount,
      notes: map['notes'] as String?,
      customerName: map['customer_name'] as String?,
      orderNumber: map['order_number'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      'notes': notes,
      'customer_name': customerName,
      'order_number': orderNumber,
    };
  }

  DailySalesModel copyWith({
    String? id,
    DateTime? date,
    double? amount,
    double? cashAmount,
    double? cardAmount,
    String? notes,
    String? customerName,
    String? orderNumber,
  }) {
    return DailySalesModel(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      cashAmount: cashAmount ?? this.cashAmount,
      cardAmount: cardAmount ?? this.cardAmount,
      notes: notes ?? this.notes,
      customerName: customerName ?? this.customerName,
      orderNumber: orderNumber ?? this.orderNumber,
    );
  }
}

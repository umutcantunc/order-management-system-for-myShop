import 'package:cloud_firestore/cloud_firestore.dart';

class PromissoryNoteModel {
  final String id;
  final String companyId; // Şirket/Toptancı ID'si
  final String companyName; // Şirket adı (referans için)
  final List<PurchaseItem> items; // Alınan ürünler listesi
  final double totalAmount; // Toplam ücret (manuel)
  final int installmentCount; // Kaç taksit
  final DateTime purchaseDate; // Alış tarihi
  final DateTime firstPaymentDate; // İlk ödeme tarihi
  final List<PaymentSchedule> paymentSchedule; // Ödeme planı (manuel düzenlenebilir)
  final String? notes; // Notlar
  final DateTime createdAt;
  final DateTime updatedAt;

  PromissoryNoteModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.items,
    required this.totalAmount,
    required this.installmentCount,
    required this.purchaseDate,
    required this.firstPaymentDate,
    required this.paymentSchedule,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromissoryNoteModel.fromMap(Map<String, dynamic> map, String id) {
    List<PaymentSchedule> schedule = [];
    if (map['payment_schedule'] != null) {
      schedule = (map['payment_schedule'] as List)
          .map((item) => PaymentSchedule.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    // Geriye dönük uyumluluk için eski formatı kontrol et
    List<PurchaseItem> items = [];
    if (map['items'] != null) {
      items = (map['items'] as List)
          .map((item) => PurchaseItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } else {
      // Eski format: tek ürün
      items = [
        PurchaseItem(
          description: map['item_description'] ?? '',
          quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
          unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
        ),
      ];
    }

    return PromissoryNoteModel(
      id: id,
      companyId: map['company_id'] ?? '',
      companyName: map['company_name'] ?? '',
      items: items,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      installmentCount: (map['installment_count'] as num?)?.toInt() ?? 0,
      purchaseDate: (map['purchase_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firstPaymentDate: (map['first_payment_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymentSchedule: schedule,
      notes: map['notes'] as String?,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'items': items.map((item) => item.toMap()).toList(),
      'total_amount': totalAmount,
      'installment_count': installmentCount,
      'purchase_date': Timestamp.fromDate(purchaseDate),
      'first_payment_date': Timestamp.fromDate(firstPaymentDate),
      'payment_schedule': paymentSchedule.map((p) => p.toMap()).toList(),
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  PromissoryNoteModel copyWith({
    String? id,
    String? companyId,
    String? companyName,
    List<PurchaseItem>? items,
    double? totalAmount,
    int? installmentCount,
    DateTime? purchaseDate,
    DateTime? firstPaymentDate,
    List<PaymentSchedule>? paymentSchedule,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromissoryNoteModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      installmentCount: installmentCount ?? this.installmentCount,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      firstPaymentDate: firstPaymentDate ?? this.firstPaymentDate,
      paymentSchedule: paymentSchedule ?? this.paymentSchedule,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PurchaseItem {
  final String description; // Ürün açıklaması
  final double quantity; // Miktar
  final double unitPrice; // Birim fiyat

  PurchaseItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  double get subtotal => quantity * unitPrice;

  PurchaseItem copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
  }) {
    return PurchaseItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

class PaymentSchedule {
  final int installmentNumber; // Taksit numarası
  final double amount; // Taksit tutarı
  final DateTime dueDate; // Ödeme tarihi
  final bool isPaid; // Ödendi mi?

  PaymentSchedule({
    required this.installmentNumber,
    required this.amount,
    required this.dueDate,
    required this.isPaid,
  });

  factory PaymentSchedule.fromMap(Map<String, dynamic> map) {
    return PaymentSchedule(
      installmentNumber: (map['installment_number'] as num?)?.toInt() ?? 0,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: (map['due_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPaid: map['is_paid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'installment_number': installmentNumber,
      'amount': amount,
      'due_date': Timestamp.fromDate(dueDate),
      'is_paid': isPaid,
    };
  }

  PaymentSchedule copyWith({
    int? installmentNumber,
    double? amount,
    DateTime? dueDate,
    bool? isPaid,
  }) {
    return PaymentSchedule(
      installmentNumber: installmentNumber ?? this.installmentNumber,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}

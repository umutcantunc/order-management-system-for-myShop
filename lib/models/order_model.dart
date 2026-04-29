import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customOrderNumber;
  final String customerName;
  final String details;
  final String? drawingUrl;
  final String? photoUrl;
  final String status; // 'bekliyor', 'tamamlandı', 'teslim edildi'
  final DateTime? dueDate;
  final DateTime createdAt;
  final String? createdByName; // Siparişi ekleyen kişinin adı
  final String? createdByUid; // Siparişi ekleyen kişinin UID'si
  final String? completedByName; // Siparişi tamamlayan kişinin adı
  final String? completedByUid; // Siparişi tamamlayan kişinin UID'si
  final double? price; // Fiyat (opsiyonel)
  final String? productName; // Ürün adı (opsiyonel)
  final String? productColor; // Ürün rengi (opsiyonel)
  final String? customerPhone; // Müşteri telefonu (opsiyonel)
  final String? customerAddress; // Müşteri adresi (opsiyonel)
  final String? paymentType; // Ödeme tipi: 'nakit' veya 'kart' (opsiyonel)
  final List<String>? assignedUserIds; // Atanan personel ID'leri (opsiyonel)
  final DateTime? deliveredAt; // Teslim tarihi (opsiyonel)
  final bool movedToCustomers; // Müşteriler bölümüne taşındı mı

  OrderModel({
    required this.id,
    required this.customOrderNumber,
    required this.customerName,
    required this.details,
    this.drawingUrl,
    this.photoUrl,
    required this.status,
    this.dueDate,
    required this.createdAt,
    this.createdByName,
    this.createdByUid,
    this.completedByName,
    this.completedByUid,
    this.price,
    this.productName,
    this.productColor,
    this.customerPhone,
    this.customerAddress,
    this.paymentType,
    this.assignedUserIds,
    this.deliveredAt,
    this.movedToCustomers = false,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      customOrderNumber: map['custom_order_number'] ?? '',
      customerName: map['customer_name'] ?? '',
      details: map['details'] ?? '',
      drawingUrl: map['drawing_url'],
      photoUrl: map['photo_url'],
      status: map['status'] ?? 'bekliyor',
      dueDate: map['due_date'] != null
          ? (map['due_date'] as Timestamp).toDate()
          : null,
      createdAt: (map['created_at'] as Timestamp).toDate(),
      createdByName: map['created_by_name'],
      createdByUid: map['created_by_uid'],
      completedByName: map['completed_by_name'],
      completedByUid: map['completed_by_uid'],
      price: map['price']?.toDouble(),
      productName: map['product_name'],
      productColor: map['product_color'],
      customerPhone: map['customer_phone'],
      customerAddress: map['customer_address'],
      paymentType: map['payment_type'],
      assignedUserIds: map['assigned_user_ids'] != null
          ? List<String>.from(map['assigned_user_ids'])
          : null,
      deliveredAt: map['delivered_at'] != null
          ? (map['delivered_at'] as Timestamp).toDate()
          : null,
      movedToCustomers: map['moved_to_customers'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'custom_order_number': customOrderNumber,
      'customer_name': customerName,
      'details': details,
      'drawing_url': drawingUrl,
      'photo_url': photoUrl,
      'status': status,
      'due_date': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'created_at': Timestamp.fromDate(createdAt),
      'created_by_name': createdByName,
      'created_by_uid': createdByUid,
      'completed_by_name': completedByName,
      'completed_by_uid': completedByUid,
      'price': price,
      'product_name': productName,
      'product_color': productColor,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'payment_type': paymentType,
      'assigned_user_ids': assignedUserIds,
      'delivered_at': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'moved_to_customers': movedToCustomers,
    };
  }
}

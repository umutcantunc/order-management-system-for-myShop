import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerOrderInfo {
  final String orderId;
  final String orderNumber;
  final String? details; // Sipariş notları
  final String? photoUrl;
  final String? drawingUrl;
  final double? price;
  final String? paymentType;
  final DateTime? deliveredAt;

  CustomerOrderInfo({
    required this.orderId,
    required this.orderNumber,
    this.details,
    this.photoUrl,
    this.drawingUrl,
    this.price,
    this.paymentType,
    this.deliveredAt,
  });

  factory CustomerOrderInfo.fromMap(Map<String, dynamic> map) {
    return CustomerOrderInfo(
      orderId: map['order_id'] ?? '',
      orderNumber: map['order_number'] ?? '',
      details: map['details'],
      photoUrl: map['photo_url'],
      drawingUrl: map['drawing_url'],
      price: map['price']?.toDouble(),
      paymentType: map['payment_type'],
      deliveredAt: map['delivered_at'] != null
          ? (map['delivered_at'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'order_number': orderNumber,
      'details': details,
      'photo_url': photoUrl,
      'drawing_url': drawingUrl,
      'price': price,
      'payment_type': paymentType,
      'delivered_at': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
    };
  }
}

class CustomerModel {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes; // Notlar
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> orderIds; // Bu müşteriye ait sipariş ID'leri
  final List<CustomerOrderInfo> orderInfos; // Sipariş detayları (notlar, fotoğraf, kroki)

  CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.orderIds = const [],
    this.orderInfos = const [],
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map, String id) {
    return CustomerModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'],
      address: map['address'],
      notes: map['notes'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orderIds: map['order_ids'] != null
          ? List<String>.from(map['order_ids'])
          : [],
      orderInfos: map['order_infos'] != null
          ? (map['order_infos'] as List)
              .map((e) => CustomerOrderInfo.fromMap(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'order_ids': orderIds,
      'order_infos': orderInfos.map((info) => info.toMap()).toList(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? orderIds,
    List<CustomerOrderInfo>? orderInfos,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderIds: orderIds ?? this.orderIds,
      orderInfos: orderInfos ?? this.orderInfos,
    );
  }
}

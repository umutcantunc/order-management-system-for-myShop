import 'package:cloud_firestore/cloud_firestore.dart';

/// Silinen verilerin çöp kutusunda saklanması için model
class TrashModel {
  final String id;
  final String originalCollection; // Orijinal koleksiyon adı (örn: "orders", "shifts")
  final String originalId; // Orijinal doküman ID'si
  final Map<String, dynamic> data; // Orijinal veri
  final DateTime deletedAt; // Silinme tarihi
  final String? deletedBy; // Silen kullanıcı ID'si (opsiyonel)
  final String? description; // Açıklama (opsiyonel)

  TrashModel({
    required this.id,
    required this.originalCollection,
    required this.originalId,
    required this.data,
    required this.deletedAt,
    this.deletedBy,
    this.description,
  });

  factory TrashModel.fromMap(Map<String, dynamic> map, String id) {
    return TrashModel(
      id: id,
      originalCollection: map['original_collection'] ?? '',
      originalId: map['original_id'] ?? '',
      data: map['data'] as Map<String, dynamic>? ?? {},
      deletedAt: (map['deleted_at'] as Timestamp).toDate(),
      deletedBy: map['deleted_by'],
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'original_collection': originalCollection,
      'original_id': originalId,
      'data': data,
      'deleted_at': Timestamp.fromDate(deletedAt),
      'deleted_by': deletedBy,
      'description': description,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftModel {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final double? totalHours;
  final DateTime date;
  final String? note; // Admin için not alanı

  ShiftModel({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.isActive,
    this.totalHours,
    required this.date,
    this.note,
  });

  factory ShiftModel.fromMap(Map<String, dynamic> map, String id) {
    return ShiftModel(
      id: id,
      userId: map['user_id'] ?? '',
      startTime: (map['start_time'] as Timestamp).toDate(),
      endTime: map['end_time'] != null
          ? (map['end_time'] as Timestamp).toDate()
          : null,
      isActive: map['is_active'] ?? false,
      totalHours: map['total_hours']?.toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'start_time': Timestamp.fromDate(startTime),
      'end_time': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'is_active': isActive,
      'total_hours': totalHours,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
}

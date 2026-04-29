import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledNotificationModel {
  final String id;
  final String title;
  final String message;
  final List<int> selectedDays; // 1=Pazartesi, 2=Salı, ..., 7=Pazar
  final int hour; // 0-23
  final int minute; // 0-59
  final String recipientType; // 'all' veya 'selected'
  final List<String>? selectedUserIds; // Seçili kullanıcılar (recipientType='selected' ise)
  final bool isActive; // Bildirim aktif mi?
  final String createdBy; // Admin user ID
  final DateTime createdAt;
  final DateTime? lastSentAt; // Son gönderilme zamanı

  ScheduledNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.selectedDays,
    required this.hour,
    required this.minute,
    this.recipientType = 'all',
    this.selectedUserIds,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.lastSentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'selected_days': selectedDays,
      'hour': hour,
      'minute': minute,
      'recipient_type': recipientType,
      'selected_user_ids': selectedUserIds,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      'last_sent_at': lastSentAt != null ? Timestamp.fromDate(lastSentAt!) : null,
    };
  }

  factory ScheduledNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return ScheduledNotificationModel(
      id: id,
      title: map['title'] ?? 'Tunç Nur Branda',
      message: map['message'] ?? '',
      selectedDays: List<int>.from(map['selected_days'] ?? []),
      hour: map['hour'] ?? 9,
      minute: map['minute'] ?? 0,
      recipientType: map['recipient_type'] ?? 'all',
      selectedUserIds: map['selected_user_ids'] != null
          ? List<String>.from(map['selected_user_ids'])
          : null,
      isActive: map['is_active'] ?? true,
      createdBy: map['created_by'] ?? '',
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSentAt: (map['last_sent_at'] as Timestamp?)?.toDate(),
    );
  }

  ScheduledNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    List<int>? selectedDays,
    int? hour,
    int? minute,
    String? recipientType,
    List<String>? selectedUserIds,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? lastSentAt,
  }) {
    return ScheduledNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      selectedDays: selectedDays ?? this.selectedDays,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      recipientType: recipientType ?? this.recipientType,
      selectedUserIds: selectedUserIds ?? this.selectedUserIds,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastSentAt: lastSentAt ?? this.lastSentAt,
    );
  }

  // Bugün bildirim gönderilmeli mi?
  bool shouldSendToday() {
    if (!isActive) return false;
    
    final now = DateTime.now();
    final today = now.weekday; // 1=Pazartesi, 7=Pazar
    
    return selectedDays.contains(today);
  }

  // Bugün bildirim gönderildi mi?
  bool wasSentToday() {
    if (lastSentAt == null) return false;
    
    final now = DateTime.now();
    final lastSent = lastSentAt!;
    
    return now.year == lastSent.year &&
           now.month == lastSent.month &&
           now.day == lastSent.day;
  }
}

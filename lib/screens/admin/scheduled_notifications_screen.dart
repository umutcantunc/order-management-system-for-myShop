import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/scheduled_notification_model.dart';
import '../../services/firestore_service.dart';
import '../../services/scheduled_notification_service.dart';

class ScheduledNotificationsScreen extends StatefulWidget {
  const ScheduledNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledNotificationsScreen> createState() => _ScheduledNotificationsScreenState();
}

class _ScheduledNotificationsScreenState extends State<ScheduledNotificationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ScheduledNotificationService _scheduledNotificationService = ScheduledNotificationService();

  String _getDayName(int day) {
    switch (day) {
      case 1: return 'Pazartesi';
      case 2: return 'Salı';
      case 3: return 'Çarşamba';
      case 4: return 'Perşembe';
      case 5: return 'Cuma';
      case 6: return 'Cumartesi';
      case 7: return 'Pazar';
      default: return '';
    }
  }

  String _formatDays(List<int> days) {
    if (days.isEmpty) return 'Gün seçilmemiş';
    if (days.length == 7) return 'Her gün';
    
    final dayNames = days.map((d) => _getDayName(d)).toList();
    return dayNames.join(', ');
  }

  Future<void> _toggleActive(String id, bool currentValue) async {
    try {
      // Önce Firestore'dan bildirimi al
      final notification = await _firestoreService.getScheduledNotificationById(id);
      if (notification == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim bulunamadı'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      
      final newActiveValue = !currentValue;
      
      // Önce eski bildirimleri iptal et
      await _scheduledNotificationService.cancelDeviceNotification(notification);
      
      // Firestore'u güncelle
      await _firestoreService.updateScheduledNotification(id, {
        'is_active': newActiveValue,
      });
      
      // Cihazdaki bildirimleri güncelle
      if (newActiveValue) {
        // Aktif yapıldıysa cihaza kaydet
        await _scheduledNotificationService.scheduleDeviceNotification(notification.copyWith(isActive: true));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim aktif edildi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
        }
      } else {
        // Pasif yapıldıysa cihazdan kaldır (zaten yukarıda iptal edildi)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim pasif edildi'),
              backgroundColor: AppColors.textGray,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Bildirim aktif/pasif değiştirme hatası: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.mediumGray,
        title: Text(
          'Bildirimi Sil',
          style: TextStyle(color: AppColors.white),
        ),
        content: Text(
          'Bu zamanlanmış bildirimi silmek istediğinizden emin misiniz?',
          style: TextStyle(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: TextStyle(color: AppColors.textGray),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sil',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Önce Firestore'dan bildirimi al
        final notification = await _firestoreService.getScheduledNotificationById(id);
        
        // Cihazdaki bildirimleri kaldır
        if (notification != null) {
          await _scheduledNotificationService.cancelDeviceNotification(notification);
        }
        
        // Firestore'dan sil
        await _firestoreService.deleteScheduledNotification(id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim silindi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Zamanlanmış Bildirimler'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: StreamBuilder<List<ScheduledNotificationModel>>(
        stream: _firestoreService.getAllScheduledNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Zamanlanmış bildirim bulunamadı',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 16,
                ),
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final time = TimeOfDay(
                hour: notification.hour,
                minute: notification.minute,
              );

              return Card(
                color: AppColors.mediumGray,
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_formatDays(notification.selectedDays)} - ${time.format(context)}',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                  leading: Icon(
                    notification.isActive
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: notification.isActive
                        ? AppColors.primaryOrange
                        : AppColors.textGray,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mesaj:',
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Alıcı: ${notification.recipientType == 'all' ? 'Tüm Kullanıcılar' : '${notification.selectedUserIds?.length ?? 0} Personel'}',
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 12,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Aktif',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Switch(
                                    value: notification.isActive,
                                    onChanged: (value) =>
                                        _toggleActive(notification.id, notification.isActive),
                                    activeColor: AppColors.primaryOrange,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (notification.lastSentAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Son Gönderilme: ${DateFormat('dd.MM.yyyy HH:mm').format(notification.lastSentAt!)}',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _deleteNotification(notification.id),
                                icon: Icon(Icons.delete, color: AppColors.error, size: 18),
                                label: Text(
                                  'Sil',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/scheduled_notification_model.dart';
import '../services/firestore_service.dart';
import 'notification_service.dart';

class ScheduledNotificationService {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();
  
  // Zamanlanmış bildirimi cihazın bildirim sistemine kaydet
  Future<void> scheduleDeviceNotification(ScheduledNotificationModel notification) async {
    try {
      debugPrint('=== Bildirim zamanlama başlatılıyor: ${notification.id} ===');
      debugPrint('Başlık: ${notification.title}');
      debugPrint('Mesaj: ${notification.message}');
      debugPrint('Seçilen günler: ${notification.selectedDays}');
      debugPrint('Saat: ${notification.hour}:${notification.minute.toString().padLeft(2, '0')}');
      debugPrint('Aktif: ${notification.isActive}');
      
      await _notificationService.initialize();
      
      // Önce bu bildirime ait eski bildirimleri iptal et (yeniden zamanlama durumunda)
      await cancelDeviceNotification(notification);
      
      // Her seçilen gün için ayrı bildirim zamanla
      int successCount = 0;
      for (int day in notification.selectedDays) {
        try {
          // Bildirim ID'si: notification.id hash'i + gün numarası
          int notificationId = _getNotificationId(notification.id, day);
          
          // Bu gün için bir sonraki zamanı hesapla
          tz.TZDateTime scheduledTime = _getNextScheduledTime(day, notification.hour, notification.minute);
          
          debugPrint('Bildirim zamanlanıyor: ID=$notificationId, Gün=$day (${_getDayName(day)}), Zaman=$scheduledTime, Saat=${notification.hour}:${notification.minute.toString().padLeft(2, '0')}');
          
          // Bildirimi cihazın bildirim sistemine kaydet
          await _notificationService.scheduleWeeklyNotification(
            id: notificationId,
            title: notification.title,
            body: notification.message,
            weekday: day,
            hour: notification.hour,
            minute: notification.minute,
          );
          
          successCount++;
          debugPrint('Bildirim başarıyla zamanlandı: ID=$notificationId');
        } catch (e, stackTrace) {
          debugPrint('Gün $day için bildirim zamanlama hatası: $e');
          debugPrint('Stack trace: $stackTrace');
          // Bir gün için hata olsa bile diğer günler için devam et
        }
      }
      
      debugPrint('=== Zamanlanmış bildirim cihaza kaydedildi: ${notification.id} ===');
      debugPrint('Başarılı: $successCount/${notification.selectedDays.length} bildirim zamanlandı');
    } catch (e, stackTrace) {
      debugPrint('Cihaz bildirimi zamanlama hatası: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  // Gün adını al
  String _getDayName(int day) {
    switch (day) {
      case 1: return 'Pazartesi';
      case 2: return 'Salı';
      case 3: return 'Çarşamba';
      case 4: return 'Perşembe';
      case 5: return 'Cuma';
      case 6: return 'Cumartesi';
      case 7: return 'Pazar';
      default: return 'Bilinmeyen';
    }
  }
  
  // Zamanlanmış bildirimi cihazdan kaldır
  Future<void> cancelDeviceNotification(ScheduledNotificationModel notification) async {
    try {
      debugPrint('=== Bildirim iptal ediliyor: ${notification.id} ===');
      await _notificationService.initialize();
      
      // Her seçilen gün için bildirimi iptal et
      for (int day in notification.selectedDays) {
        try {
          int notificationId = _getNotificationId(notification.id, day);
          await _notificationService.cancelNotification(notificationId);
          debugPrint('Bildirim iptal edildi: ID=$notificationId, Gün=$day');
        } catch (e) {
          debugPrint('Gün $day için bildirim iptal hatası: $e');
          // Bir gün için hata olsa bile diğer günler için devam et
        }
      }
      debugPrint('=== Bildirim iptal işlemi tamamlandı: ${notification.id} ===');
    } catch (e, stackTrace) {
      debugPrint('Bildirim iptal hatası: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  // Bildirim ID'si oluştur (notification.id + gün numarası)
  int _getNotificationId(String notificationId, int day) {
    // notification.id'nin hash'ini al ve gün numarasıyla birleştir
    int hash = notificationId.hashCode;
    // Negatif olmaması için mutlak değer al ve gün numarasıyla birleştir
    return (hash.abs() * 10 + day) % 2147483647; // int max değeri
  }
  
  // Bir sonraki zamanlanmış zamanı hesapla
  tz.TZDateTime _getNextScheduledTime(int weekday, int hour, int minute) {
    try {
      final now = tz.TZDateTime.now(tz.local);
      
      // Bugünün haftanın günü (1=Pazartesi, 7=Pazar)
      int currentWeekday = now.weekday;
      
      // Haftanın günü farkı hesapla
      int daysUntilTarget = (weekday - currentWeekday) % 7;
      if (daysUntilTarget == 0) {
        // Bugün hedef gün, saat kontrolü yap
        final targetTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        if (targetTime.isBefore(now)) {
          // Bugünün saati geçtiyse, gelecek hafta
          daysUntilTarget = 7;
        }
      }
      
      // Hedef tarihi hesapla
      final targetDate = now.add(Duration(days: daysUntilTarget));
      return tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, hour, minute);
    } catch (e) {
      debugPrint('Zaman hesaplama hatası: $e');
      // Hata durumunda yarın aynı saatte döndür
      final tomorrow = tz.TZDateTime.now(tz.local).add(const Duration(days: 1));
      return tz.TZDateTime(tz.local, tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    }
  }
  
  // Tüm aktif bildirimleri cihaza yükle (uygulama başlatıldığında)
  Future<void> reloadAllScheduledNotifications() async {
    try {
      debugPrint('=== Tüm zamanlanmış bildirimler yükleniyor ===');
      
      // Bildirim servisini başlat
      await _notificationService.initialize();
      
      // Firebase'in hazır olmasını bekle
      await Future.delayed(const Duration(seconds: 2));
      
      final notifications = await _firestoreService.getActiveScheduledNotifications();
      
      debugPrint('Aktif bildirim sayısı: ${notifications.length}');
      
      if (notifications.isEmpty) {
        debugPrint('Aktif bildirim bulunamadı');
        return;
      }
      
      for (var notification in notifications) {
        if (notification.isActive) {
          try {
            debugPrint('Bildirim yükleniyor: ${notification.id} - ${notification.title}');
            await scheduleDeviceNotification(notification);
            debugPrint('Bildirim başarıyla yüklendi: ${notification.id}');
          } catch (e, stackTrace) {
            debugPrint('Bildirim yükleme hatası (${notification.id}): $e');
            debugPrint('Stack trace: $stackTrace');
            // Bir bildirim için hata olsa bile diğer bildirimler için devam et
          }
        }
      }
      
      debugPrint('=== Tüm zamanlanmış bildirimler cihaza yüklendi ===');
    } catch (e, stackTrace) {
      debugPrint('Bildirimleri yükleme hatası: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  // Zamanlanmış bildirimleri kontrol et ve gönder (eski metod - artık kullanılmıyor ama geriye dönük uyumluluk için)
  Future<void> checkAndSendScheduledNotifications() async {
    // Bu metod artık kullanılmıyor çünkü bildirimler cihazın bildirim sistemi tarafından gönderiliyor
    // Ancak geriye dönük uyumluluk için bırakıyoruz
    debugPrint('checkAndSendScheduledNotifications çağrıldı - artık kullanılmıyor');
  }

  // Zamanlanmış bildirimi gönder (Firestore'a kaydet)
  Future<void> _sendScheduledNotification(ScheduledNotificationModel notification) async {
    try {
      final timestamp = DateTime.now();
      final firestore = FirebaseFirestore.instance;

      debugPrint('Zamanlanmış bildirim gönderiliyor: ${notification.id}');

      // Alıcıları belirle
      List<String> recipientIds = [];

      if (notification.recipientType == 'all') {
        // Tüm kullanıcıları al
        final usersSnapshot = await firestore.collection('users').get();
        recipientIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      } else if (notification.recipientType == 'selected' && notification.selectedUserIds != null) {
        recipientIds = notification.selectedUserIds!;
      }

      // Her alıcıya bildirim gönder
      for (var userId in recipientIds) {
        await firestore.collection('notifications').add({
          'user_id': userId,
          'title': notification.title,
          'message': notification.message,
          'created_at': Timestamp.fromDate(timestamp),
          'read': false,
          'scheduled_notification_id': notification.id,
        });
      }

      // Son gönderilme zamanını güncelle
      await _firestoreService.updateScheduledNotification(notification.id, {
        'last_sent_at': Timestamp.fromDate(timestamp),
      });

      debugPrint('Zamanlanmış bildirim başarıyla gönderildi: ${notification.id}');
    } catch (e) {
      debugPrint('Zamanlanmış bildirim gönderme hatası: $e');
      rethrow;
    }
  }

  // Periyodik kontrol başlat (artık kullanılmıyor)
  void startPeriodicCheck() {
    // Bildirimler artık cihazın bildirim sistemi tarafından gönderiliyor
    // Ancak uygulama başlatıldığında tüm bildirimleri yükle
    reloadAllScheduledNotifications();
  }
}

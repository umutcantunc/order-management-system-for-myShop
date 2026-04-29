import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

// Web için bildirim handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background bildirim alındı: ${message.messageId}');
  debugPrint('Başlık: ${message.notification?.title}');
  debugPrint('Mesaj: ${message.notification?.body}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  bool _initialized = false;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final Set<String> _processedNotificationIds = {}; // İşlenmiş bildirim ID'lerini takip et
  String? _fcmToken;

  Future<void> initialize() async {
    if (_initialized) return;

    // Web için FCM başlat
    if (kIsWeb) {
      await _initializeWebNotifications();
    } else {
      // Mobile için local notifications başlat
      await _initializeMobileNotifications();
    }

    _initialized = true;
    
    // Firestore'dan bildirimleri dinle (kullanıcı giriş yapınca)
    try {
      _listenToNotifications();
    } catch (e) {
      debugPrint('Bildirim dinleme başlatma hatası: $e');
    }
  }

  // Web için bildirim başlatma
  Future<void> _initializeWebNotifications() async {
    try {
      debugPrint('=== Web bildirim servisi başlatılıyor ===');
      
      _messaging = FirebaseMessaging.instance;
      
      // Bildirim izni iste
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      debugPrint('Web bildirim izni durumu: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Web bildirim izni verildi');
        
        // FCM token al
        _fcmToken = await _messaging!.getToken();
        debugPrint('FCM Token: $_fcmToken');
        
        // Token'ı Firestore'a kaydet
        await _saveFcmToken(_fcmToken);
        
        // Token yenilendiğinde güncelle
        _messaging!.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _saveFcmToken(newToken);
        });
        
        // Foreground bildirimleri dinle
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Foreground bildirim alındı: ${message.notification?.title}');
          _showWebNotification(
            title: message.notification?.title ?? 'Tunç Nur Branda',
            body: message.notification?.body ?? '',
          );
        });
        
        // Background bildirimleri dinle
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        
        debugPrint('Web bildirim servisi başarıyla başlatıldı');
      } else {
        debugPrint('Web bildirim izni reddedildi');
      }
    } catch (e) {
      debugPrint('Web bildirim başlatma hatası: $e');
    }
  }

  // Mobile için bildirim başlatma
  Future<void> _initializeMobileNotifications() async {
    // Bildirim izinlerini kontrol et ve iste
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
      debugPrint('Bildirim izni durumu: ${await Permission.notification.status}');
    } catch (e) {
      debugPrint('Bildirim izni kontrolü hatası: $e');
    }

    // Timezone verilerini yükle
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android ayarları
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS ayarları
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // InitializationSettings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Bildirimleri başlat
    final bool? initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (initialized == true) {
      debugPrint('Bildirim servisi başarıyla başlatıldı');
    } else {
      debugPrint('Bildirim servisi başlatılamadı');
    }

    // Android için bildirim kanalları oluştur
    await _createNotificationChannel();
    await _createManualNotificationChannel();
    await _createScheduledNotificationChannel();

    // FCM başlat (mobile için de)
    try {
      _messaging = FirebaseMessaging.instance;
      
      // FCM token al
      _fcmToken = await _messaging!.getToken();
      debugPrint('FCM Token: $_fcmToken');
      
      // Token'ı Firestore'a kaydet
      await _saveFcmToken(_fcmToken);
      
      // Token yenilendiğinde güncelle
      _messaging!.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFcmToken(newToken);
      });
      
      // Foreground bildirimleri dinle
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground bildirim alındı: ${message.notification?.title}');
        showNotification(
          title: message.notification?.title ?? 'Tunç Nur Branda',
          body: message.notification?.body ?? '',
        );
      });
      
      // Background bildirimleri dinle
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('FCM başlatma hatası: $e');
    }
  }

  // FCM token'ı Firestore'a kaydet
  Future<void> _saveFcmToken(String? token) async {
    if (token == null) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      });
      
      debugPrint('FCM token Firestore\'a kaydedildi');
    } catch (e) {
      debugPrint('FCM token kaydetme hatası: $e');
    }
  }

  // Web bildirimi göster
  Future<void> _showWebNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      // Web Push API kullan
      try {
        // Service Worker üzerinden bildirim göster
        // Bu kısım service worker'ın yüklenmesini bekler
        await _showWebPushNotification(title: title, body: body);
      } catch (e) {
        debugPrint('Web bildirim gösterme hatası: $e');
      }
    }
  }

  // Web Push bildirimi göster
  Future<void> _showWebPushNotification({
    required String title,
    required String body,
  }) async {
    // Web Push API ile bildirim göster
    // Bu kısım tarayıcının Notification API'sini kullanır
    if (kIsWeb) {
      // JavaScript interop kullanarak bildirim göster
      // Ancak bu kısım için service worker gerekiyor
      // Şimdilik FCM'in kendi bildirim sistemini kullanıyoruz
      debugPrint('Web bildirim: $title - $body');
    }
  }

  // Firestore'dan bildirimleri dinle
  void _listenToNotifications() {
    try {
      // Önceki listener varsa iptal et
      _notificationSubscription?.cancel();
      _processedNotificationIds.clear();
      
      // Firebase henüz hazır olmayabilir, biraz bekle
      Future.delayed(const Duration(seconds: 2), () {
        try {
          // Kullanıcı giriş yapana kadar bekle
          FirebaseAuth.instance.authStateChanges().listen((user) {
            if (user == null) {
              // Kullanıcı çıkış yaptıysa listener'ı iptal et
              _notificationSubscription?.cancel();
              _processedNotificationIds.clear();
              return;
            }
            
            try {
              // Önceki listener varsa iptal et (birden fazla listener oluşmasını önle)
              _notificationSubscription?.cancel();
              
              // Firestore index hatası önlemek için sadece user_id ile sorgula
              _notificationSubscription = FirebaseFirestore.instance
                  .collection('notifications')
                  .where('user_id', isEqualTo: user.uid)
                  .where('read', isEqualTo: false)
                  .snapshots()
                  .listen((snapshot) async {
                    try {
                      if (snapshot.docs.isEmpty) return;
                      
                      // Yeni eklenen veya değişen bildirimleri işle
                      for (var docChange in snapshot.docChanges) {
                        // Sadece eklenen bildirimleri işle (modify edilmiş olanları tekrar işleme)
                        if (docChange.type != DocumentChangeType.added) continue;
                        
                        final notificationDoc = docChange.doc;
                        final notificationId = notificationDoc.id;
                        
                        // Eğer bu bildirim daha önce işlendiyse, tekrar işleme
                        if (_processedNotificationIds.contains(notificationId)) {
                          continue;
                        }
                        
                        final data = notificationDoc.data();
                        if (data == null) continue;
                        final isRead = data['read'] as bool? ?? false;
                        
                        // Sadece okunmamış bildirimleri göster
                        if (!isRead) {
                          // ÖNCE işleniyor olarak işaretle (tekrar gösterilmesini önlemek için)
                          _processedNotificationIds.add(notificationId);
                          
                          // Bildirimi HEMEN okundu olarak işaretle (tekrar gösterilmesini önlemek için)
                          try {
                            await notificationDoc.reference.update({'read': true});
                          } catch (e) {
                            debugPrint('Bildirim okundu işaretleme hatası: $e');
                          }
                          
                          // Bildirimi göster
                          final title = (data['title'] as String?) ?? 'Tunç Nur Branda';
                          final message = (data['message'] as String?) ?? '';
                          
                          if (message.isNotEmpty) {
                            await showNotification(
                              title: title,
                              body: message,
                              notificationId: DateTime.now().millisecondsSinceEpoch % 100000,
                            ).catchError((error) {
                              debugPrint('Bildirim gösterme hatası: $error');
                            });
                          }
                        }
                      }
                    } catch (e) {
                      debugPrint('Bildirim işleme hatası: $e');
                    }
                  }, onError: (error) {
                    debugPrint('Bildirim dinleme hatası: $error');
                  });
            } catch (e) {
              debugPrint('Firestore sorgu hatası: $e');
            }
          }, onError: (error) {
            debugPrint('Auth state hatası: $error');
          });
        } catch (e) {
          debugPrint('Firebase başlatma hatası: $e');
        }
      });
    } catch (e) {
      debugPrint('Bildirim dinleme başlatma hatası: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    if (kIsWeb) return; // Web'de kanal oluşturma gerekmez
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_reminder_channel',
      'Günlük Hatırlatmalar',
      description: 'Her sabah mesai başlatma hatırlatmaları',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Bildirime tıklandığında ne yapılacak
  }

  Future<void> scheduleDailyReminder() async {
    if (kIsWeb) {
      debugPrint('Web\'de günlük bildirim zamanlama desteklenmiyor');
      return;
    }
    
    await initialize();

    try {
      await _notifications.cancel(0);

      final scheduledTime = _nextInstanceOfNineAM();
      
      debugPrint('Günlük bildirim zamanlandı: ${scheduledTime.toString()}');
      
      await _notifications.zonedSchedule(
        0,
        'Tunç Nur Branda',
        'Hayırlı sabahlar, dükkana geldiğinizde uygulamaya girerek mesai başlata basın.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'Günlük Hatırlatmalar',
            channelDescription: 'Her sabah mesai başlatma hatırlatmaları',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      debugPrint('Günlük bildirim başarıyla zamanlandı');
    } catch (e) {
      debugPrint('Günlük bildirim zamanlama hatası: $e');
      rethrow;
    }
  }

  tz.TZDateTime _nextInstanceOfNineAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      9,
      0,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) {
      debugPrint('Web\'de bildirim iptal desteklenmiyor');
      return;
    }
    await _notifications.cancelAll();
  }

  // Anlık bildirim göster
  Future<void> showNotification({
    required String title,
    required String body,
    int notificationId = 1,
  }) async {
    await initialize();

    if (kIsWeb) {
      // Web için bildirim göster
      await _showWebNotification(title: title, body: body);
    } else {
      // Mobile için bildirim göster
      await _notifications.show(
        notificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'manual_notifications_channel',
            'Manuel Bildirimler',
            channelDescription: 'Admin tarafından gönderilen bildirimler',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  Future<void> _createManualNotificationChannel() async {
    if (kIsWeb) return;
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'manual_notifications_channel',
      'Manuel Bildirimler',
      description: 'Admin tarafından gönderilen bildirimler',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _createScheduledNotificationChannel() async {
    if (kIsWeb) return;
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'scheduled_notifications_channel',
      'Zamanlanmış Bildirimler',
      description: 'Zamanlanmış bildirimler',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Haftalık tekrarlanan bildirim zamanla
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1=Pazartesi, 7=Pazar
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) {
      debugPrint('Web\'de zamanlanmış bildirim desteklenmiyor, FCM kullanılmalı');
      // Web için FCM scheduled messages kullanılabilir
      // Şimdilik sadece log yazdırıyoruz
      return;
    }
    
    await initialize();
    await _createScheduledNotificationChannel();

    try {
      debugPrint('=== Haftalık bildirim zamanlanıyor ===');
      debugPrint('ID: $id');
      debugPrint('Başlık: $title');
      debugPrint('Mesaj: $body');
      debugPrint('Gün: $weekday (${_getWeekdayName(weekday)})');
      debugPrint('Saat: $hour:${minute.toString().padLeft(2, '0')}');
      
      final now = tz.TZDateTime.now(tz.local);
      int currentWeekday = now.weekday;
      
      debugPrint('Şu anki gün: $currentWeekday (${_getWeekdayName(currentWeekday)})');
      debugPrint('Şu anki zaman: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      
      int daysUntilTarget = (weekday - currentWeekday) % 7;
      if (daysUntilTarget == 0) {
        final targetTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        if (targetTime.isBefore(now)) {
          daysUntilTarget = 7;
          debugPrint('Bugünün saati geçti, gelecek hafta zamanlanıyor');
        } else {
          debugPrint('Bugün zamanlanıyor');
        }
      } else {
        debugPrint('$daysUntilTarget gün sonra zamanlanıyor');
      }
      
      final targetDate = now.add(Duration(days: daysUntilTarget));
      final scheduledTime = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, hour, minute);
      
      debugPrint('Zamanlanan tarih: $scheduledTime');
      debugPrint('Kalan süre: ${scheduledTime.difference(now).inHours} saat ${scheduledTime.difference(now).inMinutes % 60} dakika');
      
      // Android için exactAllowWhileIdle kullan - uygulama kapalıyken de çalışır
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_notifications_channel',
            'Zamanlanmış Bildirimler',
            channelDescription: 'Zamanlanmış bildirimler',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            ongoing: false,
            autoCancel: true,
            showWhen: true,
            when: scheduledTime.millisecondsSinceEpoch,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Uygulama kapalıyken de çalışır
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Her hafta aynı gün ve saatte tekrar et
      );
      
      debugPrint('Haftalık bildirim başarıyla zamanlandı: ID=$id');
      debugPrint('=== Bildirim zamanlama tamamlandı ===');
      
      // Bildirimin zamanlandığını doğrula
      try {
        final pendingNotifications = await _notifications.pendingNotificationRequests();
        final scheduledNotifications = pendingNotifications.where((n) => n.id == id).toList();
        if (scheduledNotifications.isNotEmpty) {
          debugPrint('Bildirim doğrulandı: ID=${scheduledNotifications.first.id}, Başlık=${scheduledNotifications.first.title}');
        } else {
          debugPrint('UYARI: Bildirim zamanlandı ama bekleyen bildirimler listesinde bulunamadı');
        }
      } catch (e) {
        debugPrint('Bildirim doğrulama hatası (görmezden geliniyor): $e');
      }
    } catch (e, stackTrace) {
      debugPrint('Haftalık bildirim zamanlama hatası: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  String _getWeekdayName(int weekday) {
    switch (weekday) {
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

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) {
      debugPrint('Web\'de bildirim iptal desteklenmiyor');
      return;
    }
    
    try {
      debugPrint('Bildirim iptal ediliyor: ID=$id');
      await _notifications.cancel(id);
      debugPrint('Bildirim başarıyla iptal edildi: ID=$id');
    } catch (e, stackTrace) {
      debugPrint('Bildirim iptal hatası: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // FCM token'ı al
  String? get fcmToken => _fcmToken;
}

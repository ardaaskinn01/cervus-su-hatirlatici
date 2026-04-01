import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/user_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. ZAMAN DİLİMLERİNİ BAŞLAT
    tz.initializeTimeZones();

    // 2. ANDROID AYARLARI
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. IOS AYARLARI (Zaten 15.0 hedefimiz var)
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 4. LOCAL BAŞLATMA
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(settings);

    // 5. 🔥 FIREBASE MESSAGING AYARLARI (P8 sonrası kritik adım)
    await _setupFirebaseMessaging();
  }

  Future<void> _setupFirebaseMessaging() async {
    // IOS İZİNLERİ İSTE
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Kullanıcı bildirim izni verdi.');
      
      // 🔑 FCM TOKEN AL (Test Mesajı İçin Gereklidir)
      String? token = await _fcm.getToken();
      debugPrint('🔑 FCM TOKEN: $token');
      // İleride bu token'ı Firestore'a kaydedeceğiz.
    } else {
      debugPrint('❌ Kullanıcı bildirim iznini reddetti.');
    }

    // ÖN PLANDA GELEN BİLDİRİMLERİ YAKALA (App açıkken)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Ön planda bildirim geldi: ${message.notification?.title}');
      
      // Gelen bildirimi Local Notification ile gösterelim (Ekranda gözüksün diye)
      if (message.notification != null) {
        _showForegroundNotification(message);
      }
    });
  }

  // APP AÇIKKEN GELEN MESAJI GÖSTERME (IOS/Android)
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'push_notifications', 
        'Push Mesajları',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );

    await _notifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
    );
  }

  // 💦 LOKAL SU HATIRLATICI PLANLAMA
  Future<void> scheduleNextReminder() async {
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return;

    await cancelAllReminders();

    final userBox = Hive.box<UserModel>('userBox');
    if (userBox.isEmpty) return;

    final user = userBox.get('currentUser');
    if (user == null) return;

    DateTime scheduledTime = DateTime.now().add(const Duration(minutes: 2));

    if (_isUserSleeping(scheduledTime, user.wakeUpTime, user.sleepTime)) {
      DateTime now = DateTime.now();
      List<String> wakeParts = user.wakeUpTime.split(':');
      DateTime wakeToday = DateTime(now.year, now.month, now.day, int.parse(wakeParts[0]), int.parse(wakeParts[1]));
      
      if (now.isAfter(wakeToday)) {
        scheduledTime = wakeToday.add(const Duration(days: 1));
      } else {
        scheduledTime = wakeToday;
      }
    }

    await _notifications.zonedSchedule(
      1,
      'Su Vakti! 🌊',
      'Vücudunun su dengesini korumak için bir bardak su içmelisin.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'water_reminders',
          'Su Hatırlatıcı',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  bool _isUserSleeping(DateTime time, String wakeUp, String sleep) {
    int timeMins = time.hour * 60 + time.minute;
    List<String> wParts = wakeUp.split(':');
    List<String> sParts = sleep.split(':');
    int wakeMins = int.parse(wParts[0]) * 60 + int.parse(wParts[1]);
    int sleepMins = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);

    if (sleepMins > wakeMins) {
      return timeMins >= sleepMins || timeMins < wakeMins;
    } else {
      return timeMins >= sleepMins && timeMins < wakeMins;
    }
  }
}

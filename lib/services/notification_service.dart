import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../providers/water_provider.dart';

/// ============================================================
/// 🔔 NOTIFICATION SERVICE (BEYAZ EKRAN ÇÖZÜMLÜ & STABİL)
/// ============================================================
/// Arka planda su ekleme işleminin Firestore'a yansıması için
/// Firebase'in ve Kullanıcı Verilerinin doğru yüklenmesi gerekir.
/// ============================================================

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  debugPrint('📢 Arka planda bildirim eylemi: ${response.actionId}');
  WidgetsFlutterBinding.ensureInitialized();
  
  int amount = 0;
  if (response.actionId == NotificationService.action100ml) amount = 100;
  else if (response.actionId == NotificationService.action200ml) amount = 200;
  if (amount <= 0) return;

  try {
    // 1. Firebase'i arka planda başlat
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    // 2. Hive'ı başlat ve kullanıcıyı yükle
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    final userBox = await Hive.openBox<UserModel>('userBox');
    await Hive.openBox('settings');
    await Hive.openBox('dailyData');

    final user = userBox.get('currentUser');
    if (user == null) {
      debugPrint('🚨 Arka Plan: Kullanıcı bulunamadı, işlem iptal.');
      return;
    }

    // 3. WaterProvider BYPASS → Doğrudan Firestore'a Yaz 🎯
    // (WaterProvider stream tabanlıdır, arka planda _user null kalır, addWater sessizce başarısız olur)
    final now = DateTime.now();
    final dateKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final saat = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final uid = now.millisecondsSinceEpoch.toString();

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.firebaseId)
        .collection('gunler')
        .doc(dateKey);

    await docRef.set({
      'gunlukMiktar': FieldValue.increment(amount),
      'tarih': dateKey,
      'suIcildi': FieldValue.arrayUnion([
        {'uid': uid, 'saat': saat, 'miktar': amount}
      ]),
    }, SetOptions(merge: true));

    debugPrint('✅ Arka Plan: $amount ml → Firestore\'a başarıyla yazıldı.');
  } catch (e) {
    debugPrint('🚨 Arka Plan Hatası: $e');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const String action100ml = 'DRINK_100ML';
  static const String action200ml = 'DRINK_200ML';
  static const String categoryId = 'WATER_CATEGORY';

  Future<void> initialize() async {
    tz.initializeTimeZones();

    final List<DarwinNotificationCategory> darwinCategories = [
      DarwinNotificationCategory(
        categoryId,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(action100ml, '💧 100 ml İç'),
          DarwinNotificationAction.plain(action200ml, '🌊 200 ml İç'),
        ],
        options: <DarwinNotificationCategoryOption>{},
      ),
    ];

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: darwinCategories,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Ön planda tıklanırsa da aynı mantığı çalıştıralım
        if (response.actionId == action100ml) {
          _handleDrinkAction(100);
        } else if (response.actionId == action200ml) {
          _handleDrinkAction(200);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    debugPrint('🔔 Lokal Bildirim Servisi Hazır');
  }

  // ÖN PLAN TIKLAMA YÖNETİMİ 👇🎯
  void _handleDrinkAction(int amount) async {
    debugPrint('📢 Ön planda bildirimden su eklendi: $amount ml');
    final wp = WaterProvider();
    await wp.recalculateGoal(); // Kullanıcı verisini yükle
    await wp.addWater(amount); // Kaydet
  }

  Future<void> scheduleNextReminder() async {
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return;

    await cancelAllReminders();

    final userBox = Hive.box<UserModel>('userBox');
    if (userBox.isEmpty) return;

    final user = userBox.get('currentUser');
    if (user == null) return;

    DateTime scheduledTime = DateTime.now().add(const Duration(minutes: 1));

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
      'Vücudunun su dengesini korumak için bir bardak su içmelisin.\n(Seçenekler için basılı tutun)',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'water_reminders',
          'Su Hatırlatıcı',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(action100ml, '💧 100 ml İç'),
            AndroidNotificationAction(action200ml, '🌊 200 ml İç'),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          categoryIdentifier: categoryId,
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

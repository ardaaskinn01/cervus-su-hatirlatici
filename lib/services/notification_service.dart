import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';
import '../firebase_options.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'water_reminder_category',
          actions: [
            DarwinNotificationAction.plain('ADD_100', '+100 ml Ekle'),
            DarwinNotificationAction.plain('ADD_200', '+200 ml Ekle'),
          ],
          options: {
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationAction(response.payload ?? response.actionId ?? '');
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse notificationResponse) {
    _handleNotificationAction(notificationResponse.payload ?? notificationResponse.actionId ?? '');
  }

  static Future<void> _handleNotificationAction(String actionKey) async {
    if (actionKey == 'ADD_100' || actionKey == 'ADD_200') {
      final amount = actionKey == 'ADD_100' ? 100 : 200;
      await _saveWaterToFirebase(amount);
    }
  }

  static Future<void> _saveWaterToFirebase(int amount) async {
    // Isolate ortamında Firebase ve Hive kontrolü
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    
    if (!Hive.isBoxOpen('userBox')) {
      await Hive.openBox<UserModel>('userBox');
    }

    final userBox = Hive.box<UserModel>('userBox');
    final user = userBox.get('currentUser');
    if (user == null) return;

    final now = DateTime.now();
    final dateKey = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final saat = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.firebaseId)
        .collection('gunler')
        .doc(dateKey);

    await docRef.set({
      'gunlukMiktar': FieldValue.increment(amount),
      'suIcildi': FieldValue.arrayUnion([{
        'uid': DateTime.now().millisecondsSinceEpoch.toString(),
        'saat': saat, 
        'miktar': amount
      }]),
    }, SetOptions(merge: true));

    // Bir sonraki bildirimi planla
    NotificationService().scheduleNextReminder();
  }

  Future<void> scheduleNextReminder() async {
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return;

    await cancelAllReminders();

    if (!Hive.isBoxOpen('userBox')) await Hive.openBox<UserModel>('userBox');
    final userBox = Hive.box<UserModel>('userBox');
    if (userBox.isEmpty) return;

    final user = userBox.get('currentUser');
    if (user == null) return;

    DateTime scheduledTime = DateTime.now().add(const Duration(minutes: 2));

    if (_isUserSleeping(scheduledTime, user.wakeUpTime, user.sleepTime)) {
      DateTime now = DateTime.now();
      List<String> wakeParts = user.wakeUpTime.split(':');
      DateTime wakeTimeToday = DateTime(now.year, now.month, now.day, int.parse(wakeParts[0]), int.parse(wakeParts[1]));
      scheduledTime = now.isAfter(wakeTimeToday) ? wakeTimeToday.add(const Duration(days: 1)) : wakeTimeToday;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'water_reminders',
      'Su Hatırlatıcı Bildirimleri',
      channelDescription: 'Su içmen gerektiğini hatırlatan bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('ADD_100', '+100 ml İçtim'),
        AndroidNotificationAction('ADD_200', '+200 ml İçtim'),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'water_reminder_category',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      1,
      'Su Vakti! 🌊',
      'Vücudunun su dengesini korumak için bir bardak su içmelisin.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'WATER_REMINDER',
    );

  }

  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
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

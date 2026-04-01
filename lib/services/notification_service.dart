import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/user_model.dart';

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

  // Background action handler
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse notificationResponse) {
    _handleNotificationAction(notificationResponse.payload ?? notificationResponse.actionId ?? '');
  }

  static void _handleNotificationAction(String actionKey) {
    print("Notification Action: $actionKey");
    if (actionKey == 'ADD_100' || actionKey == 'ADD_200') {
      // Burada Hive'a su ekleme mantığını tetikleyebiliriz
      // Ancak UI açık değilse direkt Hive üzerinden işlem yapılır
      final amount = actionKey == 'ADD_100' ? 100 : 200;
      _saveWaterToHive(amount);
    }
  }

  static void _saveWaterToHive(int amount) {
    if (!Hive.isBoxOpen('userBox')) return;
    final userBox = Hive.box<UserModel>('userBox');
    final user = userBox.get('currentUser');
    if (user != null) {
      user.currentWater += amount;
      user.save();
      print("Water added from notification: $amount ml");
    }
  }

  Future<void> scheduleNextReminder() async {
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return;

    await cancelAllReminders();

    final userBox = Hive.box<UserModel>('userBox');
    if (userBox.isEmpty) return;

    final user = userBox.get('currentUser');
    if (user == null) return;

    // 2 dakika sonra hatırla (Test amaçlı, normalde 2 saat olabilir)
    DateTime scheduledTime = DateTime.now().add(const Duration(minutes: 2));

    if (_isUserSleeping(scheduledTime, user.wakeUpTime, user.sleepTime)) {
      // Uyuyorsa bir sonraki uyanış saatine ertele
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

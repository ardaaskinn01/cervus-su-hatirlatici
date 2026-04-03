import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../providers/water_provider.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  debugPrint('📢 Arka planda bildirim eylemi: ${response.actionId}');
  WidgetsFlutterBinding.ensureInitialized();
  
  // FCM kaldırıldığı için Firebase init'e burada gerek yok (Sadece Hive yeterli)
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
  
  final userBox = await Hive.openBox<UserModel>('userBox');
  await Hive.openBox('settings');
  
  if (userBox.isEmpty || userBox.get('currentUser') == null) return;
  
  int amount = 0;
  if (response.actionId == NotificationService.action100ml) amount = 100;
  else if (response.actionId == NotificationService.action200ml) amount = 200;
  
  if (amount > 0) {
    final wp = WaterProvider();
    await wp.addWater(amount);
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
        if (response.actionId == action100ml) {
          _handleDrinkAction(100);
        } else if (response.actionId == action200ml) {
          _handleDrinkAction(200);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // FCM KURULUMU KALDIRILDI 🚫
    debugPrint('🔔 Lokal Bildirim Servisi Başlatıldı (FCM Devre Dışı)');
  }

  void _handleDrinkAction(int amount) {
    debugPrint('📢 Bildirimden su eklendi: $amount ml');
    final waterProvider = WaterProvider();
    waterProvider.addWater(amount);
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

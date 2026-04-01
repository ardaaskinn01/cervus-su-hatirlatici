// import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/user_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    /*
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelGroupKey: 'water_reminders_group',
          channelKey: 'water_reminders',
          channelName: 'Su Hatırlatıcı Bildirimleri',
          channelDescription: 'Su içmen gerektiğini hatırlatan bildirimler',
          defaultColor: const Color(0xFF29B6F6),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          onlyAlertOnce: true,
          playSound: true,
          criticalAlerts: true,
        )
      ],
      channelGroups: [
        NotificationChannelGroup(channelGroupKey: 'water_reminders_group', channelGroupName: 'Buzdolabı Grubu')
      ],
      debug: true,
    );

    // İzin kontrolü
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
    */
  }

  Future<void> scheduleNextReminder() async {
    /*
    // 1. KULLANICI AYARINI KONTROL ET (Notifications Toggle)
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return; // Kapalıysa kurma

    // 2. Mevcut planlanmış bildirimleri iptal et
    await cancelAllReminders();

    final userBox = Hive.box<UserModel>('userBox');
    if (userBox.isEmpty) return;

    final user = userBox.get('currentUser');
    if (user == null) return;

    // TEST İÇİN: 2 dakika sonraki vakit
    DateTime scheduledTime = DateTime.now().add(const Duration(minutes: 2));

    // Uyku kontrolü (Gece bildirim gelmez)
    if (_isUserSleeping(scheduledTime, user.wakeUpTime, user.sleepTime)) {
      // Eğer uyuyor olacaksa, bildirimi bir sonraki uyanış saatine erteleyelim
      DateTime now = DateTime.now();
      List<String> wakeParts = user.wakeUpTime.split(':');
      DateTime wakeTimeToday = DateTime(now.year, now.month, now.day, int.parse(wakeParts[0]), int.parse(wakeParts[1]));
      
      // Eğer uyanış saati çoktan geçildiyse yarına kur
      if (now.isAfter(wakeTimeToday)) {
        scheduledTime = wakeTimeToday.add(const Duration(days: 1));
      } else {
        scheduledTime = wakeTimeToday;
      }

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'water_reminders',
          title: 'Günaydın! 💧',
          body: 'Güne taze bir bardak su ile başlamaya ne dersin?',
          notificationLayout: NotificationLayout.Default,
        ),
        actionButtons: [
          NotificationActionButton(key: 'ADD_100', label: '+100 ml (Başla)', actionType: ActionType.KeepOnTop),
          NotificationActionButton(key: 'ADD_200', label: '+200 ml (Tam)', actionType: ActionType.KeepOnTop),
        ],
        schedule: NotificationCalendar.fromDate(date: scheduledTime, preciseAlarm: true, allowWhileIdle: true),
      );

    } else {
      // Normal 2 saatlik hatırlatıcı
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'water_reminders',
          title: 'Su Vakti! 🌊',
          body: 'Vücudunun su dengesini korumak için bir bardak su içmelisin.',
          notificationLayout: NotificationLayout.Default,
        ),
        actionButtons: [
          NotificationActionButton(key: 'ADD_100', label: '+100 ml İçtim', actionType: ActionType.KeepOnTop),
          NotificationActionButton(key: 'ADD_200', label: '+200 ml İçtim', actionType: ActionType.KeepOnTop),
        ],
        schedule: NotificationCalendar.fromDate(date: scheduledTime, preciseAlarm: true, allowWhileIdle: true),
      );
    }
    */
  }

  Future<void> cancelAllReminders() async {
    // await AwesomeNotifications().cancelAllSchedules();
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

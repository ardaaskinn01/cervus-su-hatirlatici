import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../providers/water_provider.dart';

/// ============================================================
/// 🔔 NOTIFICATION SERVICE — PRODUCTION LEVEL v3
/// ============================================================
/// BİLDİRİM KATEGORİLERİ:
///
/// [Akıllı Su Hatırlatıcı — Escalating]
///   ID 10 → Son sudan 2 saat sonra  (nazik)
///   ID 11 → Son sudan 4 saat sonra  (orta)
///   ID 12 → Son sudan 8 saat sonra  (sert)
///   ID 13 → 24 saat hiç su eklenmedi (kritik)
///
/// [Sabah Günaydın]
///   ID 20 → Her gün, uyanma saati + 30 dk
///
/// [Re-Engagement (Uyandırma)]
///   ID 30 → 3 gün kullanılmadı
///   ID 31 → 7 gün kullanılmadı
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
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

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

    // Su eklenince son eylem zamanını güncelle ve bildirimleri yeniden planla
    final settingsBox = Hive.box('settings');
    await settingsBox.put('lastWaterTimestamp', now.millisecondsSinceEpoch);

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
  Completer<void>? _initCompleter;
  bool _isInitialized = false;

  // --- Action IDs ---
  static const String action100ml = 'DRINK_100ML';
  static const String action200ml = 'DRINK_200ML';
  static const String categoryId = 'WATER_CATEGORY';

  // --- Notification IDs ---
  static const int _id2h = 10;    // 2 saat
  static const int _id4h = 11;    // 4 saat
  static const int _id8h = 12;    // 8 saat
  static const int _id24h = 13;   // 24 saat
  static const int _idMorning = 20; // Günaydın
  static const int _id3day = 30;   // 3 gün
  static const int _id7day = 31;   // 7 gün

  // ─── INIT ────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    tz.initializeTimeZones();
    try {
      final dynamic tzResult = await FlutterTimezone.getLocalTimezone();
      // flutter_timezone may return String or an object with .identifier
      final String timeZoneName = tzResult is String
          ? tzResult
          : (tzResult.identifier as String? ?? 'UTC');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('🌍 Zaman Dilimi: $timeZoneName');
    } catch (e) {
      debugPrint('🚨 Zaman dilimi hatası, UTC kullanılıyor: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

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

    await _notifications.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == action100ml) {
          _handleDrinkAction(100);
        } else if (response.actionId == action200ml) {
          _handleDrinkAction(200);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _isInitialized = true;
    _initCompleter!.complete();
    debugPrint('🔔 Bildirim Servisi Hazır (Production Mode)');
  }

  // ─── ÖN PLAN TIKLAMA YÖNETİMİ ───────────────────────────────
  void _handleDrinkAction(int amount) async {
    debugPrint('📢 Ön planda bildirimden su eklendi: $amount ml');
    final wp = WaterProvider();
    await wp.recalculateGoal();
    await wp.addWater(amount);
    // addWater içinde scheduleEscalatingReminders() çağrılacak
  }

  // ─── ANA PLANLAMA NOKTASI ────────────────────────────────────
  /// Su eklendiğinde çağrılır. Escalating bildirimleri planlar.
  Future<void> scheduleEscalatingReminders() async {
    await initialize();
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return;

    // Eski su hatırlatıcılarını iptal et (günaydın ve re-engagement dokunma)
    await _cancelReminderIds([_id2h, _id4h, _id8h, _id24h]);

    final userBox = Hive.box<UserModel>('userBox');
    final user = userBox.get('currentUser');
    if (user == null) return;

    final now = DateTime.now();

    // Son eylem zamanını kaydet
    await Hive.box('settings').put('lastWaterTimestamp', now.millisecondsSinceEpoch);
    await Hive.box('settings').put('lastAppOpenDate', _formatDate(now));

    await _schedule2hReminder(now, user);
    await _schedule4hReminder(now, user);
    await _schedule8hReminder(now, user);
    await _schedule24hReminder(now, user);

    debugPrint('✅ Escalating bildirimler planlandı: ${now.toString()}');
  }

  /// Schedules the next reminder (legacy compat — calls scheduleEscalatingReminders)
  Future<void> scheduleNextReminder() async {
    await scheduleEscalatingReminders();
  }

  // ─── SABAH GÜN AÇILIŞ BİLDİRİMİ ────────────────────────────
  /// Uygulama açıldığında veya kullanıcı kaydedildiğinde çağrılır.
  /// Her güne ait saati, wakeUpTime + 30 dk olarak planlar.
  Future<void> scheduleMorningGreeting() async {
    await initialize();
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return;

    final userBox = Hive.box<UserModel>('userBox');
    final user = userBox.get('currentUser');
    if (user == null) return;

    await _cancelReminderIds([_idMorning]);

    final parts = user.wakeUpTime.split(':');
    final wakeHour = int.tryParse(parts[0]) ?? 7;
    final wakeMin = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 30;

    // Uyanış + 30 dakika
    final now = DateTime.now();
    int targetHour = wakeHour;
    int targetMin = wakeMin + 30;
    if (targetMin >= 60) {
      targetHour += 1;
      targetMin -= 60;
    }
    if (targetHour >= 24) targetHour = 0;

    DateTime scheduledToday = DateTime(now.year, now.month, now.day, targetHour, targetMin);
    // Eğer bu gün için zaman geçtiyse yarına planla
    if (scheduledToday.isBefore(now.add(const Duration(minutes: 1)))) {
      scheduledToday = scheduledToday.add(const Duration(days: 1));
    }

    final greetings = _morningMessages();

    await _notifications.zonedSchedule(
      _idMorning,
      greetings['title']!,
      greetings['body']!,
      tz.TZDateTime.from(scheduledToday, tz.local),
      _buildNotifDetails(
        channelId: 'morning_greeting',
        channelName: 'Sabah Mesajları',
        importance: Importance.high,
        priority: Priority.high,
        withActions: true,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün tekrar et
    );

    debugPrint('🌅 Günaydın bildirimi planlandı: $scheduledToday (${greetings['title']})');
  }

  // ─── RE-ENGAGEMENT BİLDİRİMLERİ ─────────────────────────────
  /// Uygulama her açıldığında çağrılır.
  /// 3 ve 7 günlük re-engagement bildirimlerini (yeniden) planlar.
  Future<void> scheduleReEngagementNotifications() async {
    await initialize();
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return;

    await _cancelReminderIds([_id3day, _id7day]);

    final now = DateTime.now();

    // 3 gün kullanılmadı → 3 gün sonra öğlen 12:00
    final date3d = now.add(const Duration(days: 3));
    final scheduled3d = DateTime(date3d.year, date3d.month, date3d.day, 12, 0);

    // 7 gün kullanılmadı → 7 gün sonra öğlen 12:00
    final date7d = now.add(const Duration(days: 7));
    final scheduled7d = DateTime(date7d.year, date7d.month, date7d.day, 12, 0);

    await _notifications.zonedSchedule(
      _id3day,
      '💧 Seni özledik!',
      '3 gündür su içme kaydın yok. Vücudun seni bekliyor — hadi bir bardak suyla başla!',
      tz.TZDateTime.from(scheduled3d, tz.local),
      _buildNotifDetails(
        channelId: 'reengagement',
        channelName: 'Hatırlatma',
        importance: Importance.high,
        priority: Priority.defaultPriority,
        withActions: false,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    await _notifications.zonedSchedule(
      _id7day,
      '🚨 Bir haftadır görünmedin!',
      '7 gündür su kaydın yok. Sağlıklı kalmak için Cervus\'a geri dönme zamanı! 💪',
      tz.TZDateTime.from(scheduled7d, tz.local),
      _buildNotifDetails(
        channelId: 'reengagement',
        channelName: 'Hatırlatma',
        importance: Importance.max,
        priority: Priority.high,
        withActions: false,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('📅 Re-engagement bildirimleri planlandı: 3 gün=$scheduled3d | 7 gün=$scheduled7d');
  }

  // ─── ESCALATİNG BİLDİRİMLER ─────────────────────────────────

  Future<void> _schedule2hReminder(DateTime from, UserModel user) async {
    final target = from.add(const Duration(hours: 2));
    if (_isUserSleeping(target, user.wakeUpTime, user.sleepTime)) return;

    await _notifications.zonedSchedule(
      _id2h,
      '💧 Su Vakti Geldi',
      'Son 2 saattir su içmedin. Bir yudum su hem zihnini hem bedenini tazeleyecek.',
      tz.TZDateTime.from(target, tz.local),
      _buildNotifDetails(
        channelId: 'water_reminders',
        channelName: 'Su Hatırlatıcı',
        importance: Importance.high,
        priority: Priority.defaultPriority,
        withActions: true,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('⏰ [2h] Bildirim planlandı: $target');
  }

  Future<void> _schedule4hReminder(DateTime from, UserModel user) async {
    final target = from.add(const Duration(hours: 4));
    if (_isUserSleeping(target, user.wakeUpTime, user.sleepTime)) return;

    await _notifications.zonedSchedule(
      _id4h,
      '⚠️ Su İçmeyi Unuttun mu?',
      '4 saattir su kaydın yok. Vücudun yavaş yavaş susuz kalmaya başlıyor — şimdi iyi bir an!',
      tz.TZDateTime.from(target, tz.local),
      _buildNotifDetails(
        channelId: 'water_reminders',
        channelName: 'Su Hatırlatıcı',
        importance: Importance.high,
        priority: Priority.high,
        withActions: true,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('⏰ [4h] Bildirim planlandı: $target');
  }

  Future<void> _schedule8hReminder(DateTime from, UserModel user) async {
    final target = from.add(const Duration(hours: 8));
    if (_isUserSleeping(target, user.wakeUpTime, user.sleepTime)) return;

    await _notifications.zonedSchedule(
      _id8h,
      '🚨 8 Saattir Su Yok!',
      'Ciddi susuzluk sinyali! Yorgunluk, baş ağrısı, konsantrasyon kaybı olabilir. Hemen bir bardak su iç!',
      tz.TZDateTime.from(target, tz.local),
      _buildNotifDetails(
        channelId: 'water_critical',
        channelName: 'Kritik Su Uyarısı',
        importance: Importance.max,
        priority: Priority.max,
        withActions: true,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('⏰ [8h] Bildirim planlandı: $target');
  }

  Future<void> _schedule24hReminder(DateTime from, UserModel user) async {
    final target = from.add(const Duration(hours: 24));
    // 24 saatlik bildirimi uyku saatine göre kaydır
    DateTime adjusted = target;
    if (_isUserSleeping(adjusted, user.wakeUpTime, user.sleepTime)) {
      final parts = user.wakeUpTime.split(':');
      final wakeHour = int.tryParse(parts[0]) ?? 8;
      final wakeMin = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final wakeToday = DateTime(target.year, target.month, target.day, wakeHour, wakeMin);
      adjusted = wakeToday.isBefore(target) 
          ? wakeToday.add(const Duration(days: 1)) 
          : wakeToday;
    }

    await _notifications.zonedSchedule(
      _id24h,
      '🔴 24 Saattir Su Kaydın Yok!',
      'Tüm gün boyunca hiç su eklemedin. Cervus\'u aç ve küçük bir adımla yeniden başla — vücudun teşekkür edecek.',
      tz.TZDateTime.from(adjusted, tz.local),
      _buildNotifDetails(
        channelId: 'water_critical',
        channelName: 'Kritik Su Uyarısı',
        importance: Importance.max,
        priority: Priority.max,
        withActions: true,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('⏰ [24h] Bildirim planlandı: $adjusted');
  }

  // ─── YARDIMCI METODLAR ──────────────────────────────────────

  NotificationDetails _buildNotifDetails({
    required String channelId,
    required String channelName,
    required Importance importance,
    required Priority priority,
    required bool withActions,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: priority,
        actions: withActions
            ? const <AndroidNotificationAction>[
                AndroidNotificationAction(action100ml, '💧 100 ml İç'),
                AndroidNotificationAction(action200ml, '🌊 200 ml İç'),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
        categoryIdentifier: withActions ? categoryId : null,
        interruptionLevel: importance == Importance.max
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );
  }

  Map<String, String> _morningMessages() {
    // Çeşitlilik için haftanın gününe göre rotasyon
    final idx = DateTime.now().weekday % 5;
    const titles = [
      '🌅 Günaydın! Güne Su ile Başla',
      '☀️ Yeni Gün, Taze Başlangıç!',
      '🌤 Harika Bir Gün Seni Bekliyor',
      '💪 Enerjini Onayla — Su İç!',
      '🌊 Günaydın! Vücudun Hazır mı?',
    ];
    const bodies = [
      'Bugüne canlı başlamak için bir bardak su iç. Cervus senin için burada! 💧',
      'Uyanma saatin geldi! Bir bardak su, güne harika bir başlangıç yapmanı sağlar.',
      'Sabahın ilk bardak suyu metabolizmanı hızlandırır ve zihni açar. Hadi başla!',
      'Bugün de hedefine ulaşmak için ilk adımı at — bir bardak su içerek!',
      'Gece boyunca kaybettiğin suyu yerine koy. Günaydın, şampiyon! 🏆',
    ];
    return {'title': titles[idx], 'body': bodies[idx]};
  }

  bool _isUserSleeping(DateTime time, String wakeUp, String sleep) {
    int timeMins = time.hour * 60 + time.minute;
    List<String> wParts = wakeUp.split(':');
    List<String> sParts = sleep.split(':');
    int wakeMins = int.parse(wParts[0]) * 60 + int.parse(wParts[1]);
    int sleepMins = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);

    if (sleepMins > wakeMins) {
      // Uyku saati aynı gün içinde (örn 22:00 - 07:00)
      return timeMins >= sleepMins || timeMins < wakeMins;
    } else {
      // Gece yarısını geçen uyku (örn 00:00 - 06:00)
      return timeMins >= sleepMins && timeMins < wakeMins;
    }
  }

  Future<void> _cancelReminderIds(List<int> ids) async {
    for (final id in ids) {
      await _notifications.cancel(id);
    }
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
    debugPrint('🚫 Tüm bildirimler iptal edildi.');
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

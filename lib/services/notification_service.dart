import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
    // 🎯 KRİTİK DÜZELTME: Mantıksal tarih anahtarını hesapla (WaterProvider ile aynı mantık)
    final dateKey = _getLogicalDateKeyFromUser(now, user);
    final saat = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final uid = now.millisecondsSinceEpoch.toString();

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.firebaseId)
        .collection('gunler')
        .doc(dateKey);

    // Günlük hedefi de bulalım (Background'da veri tutarlılığı için)
    int dailyGoal = 2000;
    if (user.customGoal != null && user.customGoal! > 0) {
      dailyGoal = user.customGoal!;
    } else {
      double base = user.weight * 35;
      int month = now.month;
      double factor = (month >= 6 && month <= 8) ? 1.2 : 1.0;
      dailyGoal = (base * factor).round();
    }

    await docRef.set({
      'gunlukMiktar': FieldValue.increment(amount),
      'tarih': dateKey,
      'hedef': dailyGoal, // Hedef verisini de ekleyelim
      'suIcildi': FieldValue.arrayUnion([
        {'uid': uid, 'saat': saat, 'miktar': amount}
      ]),
    }, SetOptions(merge: true));

    // Su eklenince son eylem zamanını güncelle ve bildirimleri yeniden planla
    final settingsBox = Hive.box('settings');
    await settingsBox.put('lastWaterTimestamp', now.millisecondsSinceEpoch);

    // 🎯 KRİTİK DÜZELTME 2: Bildirimleri yeniden planla (Böylece hemen tekrar hatırlatmaz)
    await NotificationService().scheduleEscalatingReminders();

    debugPrint('✅ Arka Plan: $amount ml → $dateKey tarihine başarıyla yazıldı.');
  } catch (e) {
    debugPrint('🚨 Arka Plan Hatası: $e');
  }
}

// Mantıksal tarih hesaplama yardımcısı (Arka plan için)
String _getLogicalDateKeyFromUser(DateTime now, UserModel user) {
  final parts = user.sleepTime.split(':');
  final sleepHour = int.parse(parts[0]);
  final sleepMinute = int.parse(parts[1]);

  final toleranceEnd = DateTime(now.year, now.month, now.day, sleepHour, sleepMinute)
      .add(const Duration(hours: 2));

  final isSleepAfterMidnight = sleepHour < 6;

  if (isSleepAfterMidnight) {
    if (now.isBefore(toleranceEnd)) {
      return _formatDateSimple(now.subtract(const Duration(days: 1)));
    }
  } else {
    final midnight = DateTime(now.year, now.month, now.day);
    if (now.isAfter(midnight) && now.isBefore(toleranceEnd) && sleepHour > 20) {
      return _formatDateSimple(now.subtract(const Duration(days: 1)));
    }
  }
  return _formatDateSimple(now);
}

String _formatDateSimple(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

// 🔥 FCM Arka plan mesaj yakalayıcı
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📩 Arka plan FCM mesajı alındı: ${message.messageId}");
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
  static const int _id1st = 10;   // 1. hatırlatma
  static const int _id2nd = 11;   // 2. hatırlatma
  static const int _id3rd = 12;   // 3. hatırlatma
  static const int _id4th = 13;   // 4. hatırlatma
  static const int _id5th = 14;   // 5. hatırlatma (sadece 30dk presetinde)
  static const int _id24h = 15;   // 24 saat
  static const int _idMorning = 20; // Günaydın
  static const int _id3day = 30;   // 3 gün
  static const int _id7day = 31;   // 7 gün

  /// Kullanıcının seçtiği interval preset (Hive key: 'notifIntervalPreset')
  /// Değerler: 'half' | '1h' | '3h' | '4h'   — Varsayılan: '2h' (eski 2 saat davranışı)
  static String getIntervalPreset() =>
      Hive.box('settings').get('notifIntervalPreset', defaultValue: '2h') as String;

  /// Preset adına göre okunabilir etiket döndürür
  static String presetLabel(String key) {
    switch (key) {
      case 'half': return '30 Dakika';
      case '1h':   return '1 Saat';
      case '2h':   return '2 Saat (Varsayılan)';
      case '3h':   return '3 Saat';
      case '4h':   return '4 Saat';
      default:     return '2 Saat';
    }
  }

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

    // 🔥 Firebase Messaging Kurulumu
    await _setupFirebaseMessaging();

    _isInitialized = true;
    _initCompleter!.complete();
    debugPrint('🔔 Bildirim Servisi Hazır (Production Mode + FCM)');
  }

  // 🔥 Firebase Messaging Kurulumu
  Future<void> _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. İzin İste
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ FCM İzni Verildi');
    } else {
      debugPrint('⚠️ FCM İzni Reddedildi veya Sınırlı');
    }

    // 2. Token Al (Panelden manuel gönderim için lazım)
    String? token = await messaging.getToken();
    debugPrint('🔑 FCM TOKEN: $token');
    // Not: Bu token'ı buluta kaydedip oradan da otomatik bildirim çıkabilirsiniz.

    // 3. Apple için ön plan ayarları
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, 
      badge: true,
      sound: true,
    );

    // 4. Arka plan mesaj dinleyicisi
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Ön plan mesaj dinleyicisi
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Ön planda FCM mesajı alındı: ${message.notification?.title}');
      
      // Eğer mesajın bir bildirimi varsa, bunu yerel bildirim olarak gösterelim
      if (message.notification != null) {
        _notifications.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          _buildNotifDetails(
            channelId: 'fcm_default',
            channelName: 'Genel Bildirimler',
            importance: Importance.max,
            priority: Priority.high,
            withActions: false,
          ),
        );
      }
    });

    // 6. Bildirime tıklandığında uygulamayı açma (Arka plandan gelince)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🖱️ FCM Bildirimine tıklandı: ${message.messageId}');
    });
  }

  /// 🎯 Kullanıcıyı kendi özel konusuna (Topic) abone yapar.
  /// Örnek: userId 'ardaaskin' ise 'user_ardaaskin' konusuna abone olur.
  Future<void> subscribeToUserTopic(String userId) async {
    await initialize();
    try {
      // FCM Topic'leri boşluk içeremez ve özel karakter kısıtlaması vardır.
      final cleanId = userId.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
      final topicName = 'user_$cleanId';
      
      await FirebaseMessaging.instance.subscribeToTopic(topicName);
      debugPrint('🔔 Topic Aboneliği Başarılı: $topicName');
    } catch (e) {
      debugPrint('🚨 Topic Abonelik Hatası: $e');
    }
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
  /// Su eklendiğinde çağrılır. Seçili preset'e göre escalating bildirimleri planlar.
  Future<void> scheduleEscalatingReminders() async {
    await initialize();
    bool isEnabled = Hive.box('settings').get('notificationsEnabled', defaultValue: true);
    if (!isEnabled) return;

    // Tüm eskalasyon ID'lerini temizle
    await _cancelReminderIds([_id1st, _id2nd, _id3rd, _id4th, _id5th, _id24h]);

    final userBox = Hive.box<UserModel>('userBox');
    final user = userBox.get('currentUser');
    if (user == null) return;

    final now = DateTime.now();
    await Hive.box('settings').put('lastWaterTimestamp', now.millisecondsSinceEpoch);
    await Hive.box('settings').put('lastAppOpenDate', _formatDate(now));

    final preset = getIntervalPreset();
    await _scheduleByPreset(now, user, preset);

    debugPrint('✅ Escalating bildirimler planlandı [preset=$preset]: ${now.toString()}');
  }

  /// Schedules the next reminder (legacy compat — calls scheduleEscalatingReminders)
  Future<void> scheduleNextReminder() async {
    await scheduleEscalatingReminders();
  }

  // ─── PRESET ROUTİNG ─────────────────────────────────────────
  Future<void> _scheduleByPreset(DateTime from, UserModel user, String preset) async {
    switch (preset) {
      case 'half':
        // 30dk → 1s → 2s → 4s → 8s → 24s
        await _scheduleReminder(_id1st, from, const Duration(minutes: 30), user,
            '💧 Su İçme Vakti!', 'Yarım saatte bir hatırlatıyorum — bir yudum al!',
            Importance.high, Priority.defaultPriority);
        await _scheduleReminder(_id2nd, from, const Duration(hours: 1), user,
            '💧 Hâlâ Su İçmedin', 'Bir saattir bekliyor. Küçük bir yudum büyük fark yapar!',
            Importance.high, Priority.high);
        await _scheduleReminder(_id3rd, from, const Duration(hours: 2), user,
            '⚠️ 2 Saattir Su Yok', 'Vücudun su dengesini korumak için şimdi içebilirsin.',
            Importance.high, Priority.high);
        await _scheduleReminder(_id4th, from, const Duration(hours: 4), user,
            '🚨 4 Saattir Su İçmedin!', 'Susuzluk belirtileri başlayabilir. Hemen bir bardak su iç!',
            Importance.max, Priority.max);
        await _scheduleReminder(_id5th, from, const Duration(hours: 8), user,
            '🔴 8 Saat! Acil Uyarı', 'Ciddi susuzluk riski! Yorgunluk ve baş ağrısı başlamış olabilir.',
            Importance.max, Priority.max);
        await _schedule24hReminderAdaptive(from, user);
        break;

      case '1h':
        // 1s → 2s → 4s → 8s → 24s
        await _scheduleReminder(_id1st, from, const Duration(hours: 1), user,
            '💧 Su İçme Vakti!', 'Bir saattir su kaydın yok. Bir bardak su hem zihnini hem bedenini tazeleyecek.',
            Importance.high, Priority.defaultPriority);
        await _scheduleReminder(_id2nd, from, const Duration(hours: 2), user,
            '⚠️ 2 Saattir Su Yok', 'Vücudun su dengesini korumak için şimdi iç!',
            Importance.high, Priority.high);
        await _scheduleReminder(_id3rd, from, const Duration(hours: 4), user,
            '🚨 4 Saattir Su İçmedin!', 'Susuzluk belirtileri başlayabilir. Hemen bir bardak su iç!',
            Importance.max, Priority.high);
        await _scheduleReminder(_id4th, from, const Duration(hours: 8), user,
            '🔴 8 Saat! Ciddi Uyarı', 'Ciddi susuzluk riski! Yorgunluk, baş ağrısı yaşıyor olabilirsin.',
            Importance.max, Priority.max);
        await _schedule24hReminderAdaptive(from, user);
        break;

      case '3h':
        // 3s → 6s → 24s
        await _scheduleReminder(_id1st, from, const Duration(hours: 3), user,
            '💧 Su Vakti Geldi', '3 saattir su içmedin. Bir bardak su içmek için güzel bir an!',
            Importance.high, Priority.defaultPriority);
        await _scheduleReminder(_id2nd, from, const Duration(hours: 6), user,
            '🚨 6 Saattir Su Yok!', 'Artık ciddi bir süre geçti. Hemen bir bardak su iç!',
            Importance.max, Priority.high);
        await _schedule24hReminderAdaptive(from, user);
        break;

      case '4h':
        // 4s → 8s → 24s
        await _scheduleReminder(_id1st, from, const Duration(hours: 4), user,
            '💧 Su Vakti', '4 saattir su kaydın yok. Bir bardak su hem zihnini hem bedenini tazeleyecek.',
            Importance.high, Priority.defaultPriority);
        await _scheduleReminder(_id2nd, from, const Duration(hours: 8), user,
            '🚨 8 Saattir Su İçmedin!', 'Ciddi susuzluk sinyali! Yorgunluk ve baş ağrısı başlamış olabilir.',
            Importance.max, Priority.max);
        await _schedule24hReminderAdaptive(from, user);
        break;

      case '2h':
      default:
        // 2s → 4s → 8s → 24s  (varsayılan / eski davranış)
        await _scheduleReminder(_id1st, from, const Duration(hours: 2), user,
            '💧 Su Vakti Geldi', 'Son 2 saattir su içmedin. Bir yudum su hem zihnini hem bedenini tazeleyecek.',
            Importance.high, Priority.defaultPriority);
        await _scheduleReminder(_id2nd, from, const Duration(hours: 4), user,
            '⚠️ Su İçmeyi Unuttun mu?', '4 saattir su kaydın yok. Vücudun yavaş yavaş susuz kalmaya başlıyor!',
            Importance.high, Priority.high);
        await _scheduleReminder(_id3rd, from, const Duration(hours: 8), user,
            '🚨 8 Saattir Su Yok!', 'Ciddi susuzluk sinyali! Yorgunluk, baş ağrısı, konsantrasyon kaybı olabilir.',
            Importance.max, Priority.max);
        await _schedule24hReminderAdaptive(from, user);
        break;
    }
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
        subtitle: 'Günaydın!',
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
      '7 gündür su kaydın yok. Sağlıklı kalmak için Drinkly\'ye geri dönme zamanı! 💪',
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

  // ─── GENEL PLANLAYICI ────────────────────────────────────────

  /// Tek bir bildirimi `from + offset` zamanına planlar.
  Future<void> _scheduleReminder(
    int id,
    DateTime from,
    Duration offset,
    UserModel user,
    String title,
    String body,
    Importance importance,
    Priority priority,
  ) async {
    final target = from.add(offset);
    if (_isUserSleeping(target, user.wakeUpTime, user.sleepTime)) {
      debugPrint('⏰ [id=$id] Uyku saatine denk geldi, atlandı.');
      return;
    }
    final channelId = importance == Importance.max ? 'water_critical' : 'water_reminders';
    final channelName = importance == Importance.max ? 'Kritik Su Uyarısı' : 'Su Hatırlatıcı';
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(target, tz.local),
      _buildNotifDetails(
        channelId: channelId,
        channelName: channelName,
        importance: importance,
        priority: priority,
        withActions: true,
        subtitle: 'Drinkly - Su Hatırlatıcı',
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('⏰ [id=$id] Bildirim planlandı: $target');
  }

  /// 24 saatlik kritik hatırlatmayı planlar (uyku saatine göre kaydırmalı)
  Future<void> _schedule24hReminderAdaptive(DateTime from, UserModel user) async {
    final target = from.add(const Duration(hours: 24));
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
      'Tüm gün boyunca hiç su eklemedin. Drinkly\'yi aç ve küçük bir adımla yeniden başla — vücudun teşekkür edecek.',
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
    String? subtitle,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: importance,
        priority: priority,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
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
        subtitle: subtitle,
        categoryIdentifier: withActions ? categoryId : null,
        interruptionLevel: importance == Importance.max || importance == Importance.high
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
      'Bugüne canlı başlamak için bir bardak su iç. Drinkly senin için burada! 💧',
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

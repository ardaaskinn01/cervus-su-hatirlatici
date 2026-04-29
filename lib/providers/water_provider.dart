import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

/// Tek bir su içme kaydını temsil eder.
class SuKaydi {
  final String uid; // Benzersizlik için
  final String saat;
  final int miktar;

  SuKaydi({required this.uid, required this.saat, required this.miktar});

  Map<String, dynamic> toMap() => {'uid': uid, 'saat': saat, 'miktar': miktar};

  factory SuKaydi.fromMap(Map<String, dynamic> map) => SuKaydi(
        uid: map['uid'] ?? "${map['saat']}_${map['miktar']}",
        saat: map['saat'] ?? '',
        miktar: (map['miktar'] as num? ?? 0).toInt(),
      );
}

class WaterProvider extends ChangeNotifier {
  UserModel? _user;

  // Anlık oturum verileri (Firebase'den gelir)
  int _currentIntake = 0;
  int _dailyGoal = 2000;
  List<SuKaydi> _todayRecords = [];


  int get currentIntake => _currentIntake;
  int get dailyGoal => _dailyGoal;
  List<SuKaydi> get todayRecords => _todayRecords;
  List<SuKaydi> get lastFiveRecords => _todayRecords.reversed.take(5).toList();

  // Seri (Streak) hala Hive'dan
  int get streakCount => Hive.box('settings').get('streakCount', defaultValue: 0);

  // Bildirim toggle
  bool get isNotificationsEnabled =>
      Hive.box('settings').get('notificationsEnabled', defaultValue: true);

  WaterProvider() {
    recalculateGoal();
  }

  // ─── MANTIKSAL GÜN ANAHTARI ─────────────────────────────────────
  /// Uyku saati + 2 saat toleransı ile "bu an hangi güne ait?" sorusunu yanıtlar.
  String getLogicalDateKey([DateTime? forTime]) {
    final now = forTime ?? DateTime.now();
    final user = _user;
    if (user == null) return _formatDate(now);

    // Uyku saatini parse et
    final parts = user.sleepTime.split(':');
    final sleepHour = int.parse(parts[0]);
    final sleepMinute = int.parse(parts[1]);


    // Gece yarısını geçen uyku (örn 23:00 - toleransEnd 01:00 sonraki gün)
    final isSleepAfterMidnight = sleepHour < 6; // 00:00–05:59 arası "gece geç"

    if (isSleepAfterMidnight) {
      // Eğer şu an sabahın erken saatiyse (gece yatış + 2 saat içindeyse) önceki gün
      final prevDayToleranceEnd = DateTime(now.year, now.month, now.day, sleepHour, sleepMinute)
          .add(const Duration(hours: 2));
      if (now.isBefore(prevDayToleranceEnd)) {
        return _formatDate(now.subtract(const Duration(days: 1)));
      }
    } else {
      // Gece geç yatan (03:00 gibi) => tolerans 05:00'a kadar önceki gün
      final midnight = DateTime(now.year, now.month, now.day);
      final toleranceEndFull = DateTime(now.year, now.month, now.day, sleepHour, sleepMinute)
          .add(const Duration(hours: 2));
      if (now.isAfter(midnight) && now.isBefore(toleranceEndFull) && sleepHour > 20) {
        return _formatDate(now.subtract(const Duration(days: 1)));
      }
    }

    return _formatDate(now);
  }

  String _formatDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // ─── HEDEF HESAPLA & FIREBASE STREAM'E BAĞLAN ──────────────────
  Future<void> recalculateGoal() async {
    var box = Hive.box<UserModel>('userBox');
    _user = box.get('currentUser');
    if (_user == null) return;

    // Öncelik Manuel Hedefte! 🎯
    if (_user!.customGoal != null && _user!.customGoal! > 0) {
      _dailyGoal = _user!.customGoal!;
    } else {
      // Kilo * 35ml + mevsimsel çarpan (Otomatik Hesaplama)
      double base = _user!.weight * 35;
      int month = DateTime.now().month;
      double factor = (month >= 6 && month <= 8) ? 1.2 : 1.0;
      _dailyGoal = (base * factor).round();
    }

    _subscribeToTodayDocument();
    notifyListeners();
  }

  // ─── FIREBASE GERÇEK ZAMANLI STREAM ────────────────────────────
  void _subscribeToTodayDocument() {
    if (_user == null) return;
    final dateKey = getLogicalDateKey();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('gunler')
        .doc(dateKey);

    // Her günlük döküman değiştiğinde UI'ı anlık güncelle
    docRef.snapshots().listen((snap) {
      if (snap.exists) {
        final data = snap.data()!;
        _currentIntake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
        final rawList = data['suIcildi'] as List<dynamic>? ?? [];
        _todayRecords = [];
        for (int i = 0; i < rawList.length; i++) {
          final map = Map<String, dynamic>.from(rawList[i]);
          // Eğer UID yoksa (eski veri), index ile benzersiz ve stabil hale getiriyoruz.
          if (map['uid'] == null) {
            map['uid'] = "old_${map['saat']}_${map['miktar']}_$i";
          }
          _todayRecords.add(SuKaydi.fromMap(map));
        }
      } else {
        _currentIntake = 0;
        _todayRecords = [];
        // Bu günün dökümanını hedefle birlikte oluştur
        docRef.set({
          'gunlukMiktar': 0,
          'hedef': _dailyGoal,
          'suIcildi': [],
          'tarih': dateKey,
        });
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore stream hatası: $e');
    });
  }

  // ─── SU EKLE ───────────────────────────────────────────────────
  Future<void> addWater(int amount) async {
    if (amount <= 0 || _user == null) return;

    final dateKey = getLogicalDateKey();
    final now = DateTime.now();
    final saat = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('gunler')
        .doc(dateKey);

    final uid = DateTime.now().millisecondsSinceEpoch.toString();
    final yeniKaydi = SuKaydi(uid: uid, saat: saat, miktar: amount);

    await docRef.set({
      'gunlukMiktar': FieldValue.increment(amount),
      'hedef': _dailyGoal,
      'tarih': dateKey,
      'suIcildi': FieldValue.arrayUnion([yeniKaydi.toMap()]),
    }, SetOptions(merge: true));

    // Streak kontrolü
    _checkStreak();

    // Son su zamanını kaydet ve escalating bildirimleri yeniden planla
    await Hive.box('settings').put('lastWaterTimestamp', DateTime.now().millisecondsSinceEpoch);
    await Hive.box('settings').put('lastAppOpenDate', _formatDate(DateTime.now()));
    NotificationService().scheduleEscalatingReminders();
  }

  // ─── SU SİL ────────────────────────────────────────────────────
  Future<void> deleteWaterRecord(SuKaydi kaydi, [String? dateKey]) async {
    if (_user == null) return;

    final key = dateKey ?? getLogicalDateKey();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('gunler')
        .doc(key);

    await docRef.update({
      'gunlukMiktar': FieldValue.increment(-kaydi.miktar),
      'suIcildi': FieldValue.arrayRemove([kaydi.toMap()]),
    });
  }

  // ─── STREAK KONTROLÜ ───────────────────────────────────────────
  void _checkStreak() {
    if (_currentIntake + 1 >= _dailyGoal) {
      // Hedefe bu su ile ulaşıldıysa streak'i kontrol et
      String lastDate = Hive.box('settings').get('lastStreakDate', defaultValue: '');
      String today = getLogicalDateKey();
      if (lastDate != today) {
        int current = streakCount;
        Hive.box('settings').put('streakCount', current + 1);
        Hive.box('settings').put('lastStreakDate', today);
      }
    }
  }

  // ─── BİLDİRİM TOGGLE ───────────────────────────────────────────
  Future<void> toggleNotifications(bool value) async {
    await Hive.box('settings').put('notificationsEnabled', value);
    if (!value) {
      await NotificationService().cancelAllReminders();
    } else {
      await NotificationService().scheduleNextReminder();
    }
    notifyListeners();
  }

  // ─── İSTATİSTİK METODLARI ──────────────────────────────────────
  /// Son 7 güne ait istikrar listesi Firebase'den çekilir (Future tabanlı)
  Future<List<bool>> getWeeklyConsistency() async {
    if (_user == null) return List.filled(7, false);
    List<bool> result = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = _formatDate(day);
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.firebaseId)
          .collection('gunler')
          .doc(key)
          .get();
      if (snap.exists) {
        final d = snap.data()!;
        result.add((d['gunlukMiktar'] as num? ?? 0) >= (d['hedef'] as num? ?? _dailyGoal));
      } else {
        result.add(false);
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getAdvancedStats() async {
    if (_user == null) return {'avg': 0, 'rate': 0, 'status': 'Veri Bekleniyor'};
    final snaps = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('gunler')
        .orderBy('tarih', descending: true)
        .limit(30)
        .get();

    if (snaps.docs.isEmpty) return {'avg': 0, 'rate': 0, 'status': 'stats_status_waiting'};

    double total = 0;
    int success = 0;
    for (var doc in snaps.docs) {
      final d = doc.data();
      total += (d['gunlukMiktar'] as num? ?? 0);
      if ((d['gunlukMiktar'] as num? ?? 0) >= (d['hedef'] as num? ?? _dailyGoal)) success++;
    }
    int count = snaps.docs.length;
    return {
      'avg': (total / count).round(),
      'rate': ((success / count) * 100).round(),
      'status': count < 3 ? 'stats_status_analyzing' : (success / count > 0.7 ? 'stats_status_stable' : 'stats_status_low'),
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class SuKaydi {
  final String uid;
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
  int _currentIntake = 0;
  int _dailyGoal = 2000;
  List<SuKaydi> _todayRecords = [];

  int get currentIntake => _currentIntake;
  int get dailyGoal => _dailyGoal;
  List<SuKaydi> get todayRecords => _todayRecords;
  List<SuKaydi> get lastFiveRecords => _todayRecords.reversed.take(5).toList();
  int get streakCount => Hive.box('settings').get('streakCount', defaultValue: 0);

  WaterProvider() {
    recalculateGoal();
  }

  // ─── MANTIKSAL GÜN ANAHTARI ─────────────────────────────────────
  String getLogicalDateKey([DateTime? forTime]) {
    final now = forTime ?? DateTime.now();
    return _formatDate(now);
  }

  String _formatDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> recalculateGoal() async {
    var box = Hive.box<UserModel>('userBox');
    _user = box.get('currentUser');
    if (_user == null) return;
    
    _dailyGoal = (_user!.weight * 35).round();
    _subscribeToTodayDocument();
    notifyListeners();
  }

  void _subscribeToTodayDocument() {
    if (_user == null) return;
    final dateKey = getLogicalDateKey();
    FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('gunler')
        .doc(dateKey)
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        final data = snap.data()!;
        _currentIntake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
        final rawList = data['suIcildi'] as List<dynamic>? ?? [];
        _todayRecords = rawList.map((e) => SuKaydi.fromMap(Map<String, dynamic>.from(e))).toList();
      } else {
        _currentIntake = 0;
        _todayRecords = [];
      }
      notifyListeners();
    });
  }

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

    NotificationService().scheduleNextReminder();

    try {
      await docRef.set({
        'gunlukMiktar': FieldValue.increment(amount),
        'hedef': _dailyGoal,
        'tarih': dateKey,
        'suIcildi': FieldValue.arrayUnion([yeniKaydi.toMap()]),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
    } catch (_) {}

    _checkStreak();
  }

  Future<void> deleteWaterRecord(SuKaydi kaydi, [String? dateKey]) async {
    if (_user == null) return;
    final key = dateKey ?? getLogicalDateKey();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('gunler')
        .doc(key);

    try {
      await docRef.update({
        'gunlukMiktar': FieldValue.increment(-kaydi.miktar),
        'suIcildi': FieldValue.arrayRemove([kaydi.toMap()]),
      });
    } catch (_) {}
  }

  void _checkStreak() {
    if (_currentIntake + 1 >= _dailyGoal) {
      String lastDate = Hive.box('settings').get('lastStreakDate', defaultValue: '');
      String today = getLogicalDateKey();
      if (lastDate != today) {
        Hive.box('settings').put('streakCount', streakCount + 1);
        Hive.box('settings').put('lastStreakDate', today);
      }
    }
  }

  Future<List<bool>> getWeeklyConsistency() async {
    if (_user == null) return List.filled(7, false);
    List<bool> result = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      String key = _formatDate(day);
      result.add(false); // Basitleştirilmiş istatistik (Gerekirse Firebase'den çekilir)
    }
    return result;
  }

  Future<Map<String, dynamic>> getAdvancedStats() async {
    return {'avg': 0, 'rate': 0, 'status': 'Veri Analiz Ediliyor'};
  }

  Future<void> toggleNotifications(bool value) async {
    await Hive.box('settings').put('notificationsEnabled', value);
    if (!value) await NotificationService().cancelAllReminders();
    else await NotificationService().scheduleNextReminder();
    notifyListeners();
  }
}

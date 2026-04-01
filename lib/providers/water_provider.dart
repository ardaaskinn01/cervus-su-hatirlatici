import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:async'; // unawaited için gerekli
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
  int get streakCount => Hive.box('settings').get('streakCount', defaultValue: 0);

  WaterProvider() {
    recalculateGoal();
  }

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
    final dateKey = _formatDate(DateTime.now());
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
      }
      notifyListeners();
    });
  }

  String _formatDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> addWater(int amount) async {
    if (amount <= 0 || _user == null) return;

    final dateKey = _formatDate(DateTime.now());
    final now = DateTime.now();
    final saat = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('gunler')
        .doc(dateKey);

    final uid = DateTime.now().millisecondsSinceEpoch.toString();
    final yeniKaydi = SuKaydi(uid: uid, saat: saat, miktar: amount);

    // 🔥 1. BİLDİRİMİ PLANLA (GECİKMESİZ!)
    NotificationService().scheduleNextReminder();

    // 🔥 2. FIREBASE'E YAZMAYI BEKLEME (UNAWAITED!)
    // İnternet kopsa bile uygulama burada takılmayacak
    unawaited(
      docRef.set({
        'gunlukMiktar': FieldValue.increment(amount),
        'hedef': _dailyGoal,
        'tarih': dateKey,
        'suIcildi': FieldValue.arrayUnion([yeniKaydi.toMap()]),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 3)).catchError((e) {
        debugPrint("Local cache will sync Firebase later: $e");
      })
    );

    _checkStreak();
    notifyListeners();
  }

  void _checkStreak() {
    if (_currentIntake + 1 >= _dailyGoal) {
      String lastDate = Hive.box('settings').get('lastStreakDate', defaultValue: '');
      String today = _formatDate(DateTime.now());
      if (lastDate != today) {
        Hive.box('settings').put('streakCount', streakCount + 1);
        Hive.box('settings').put('lastStreakDate', today);
      }
    }
  }

  Future<void> toggleNotifications(bool value) async {
    await Hive.box('settings').put('notificationsEnabled', value);
    if (!value) await NotificationService().cancelAllReminders();
    else await NotificationService().scheduleNextReminder();
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/drink_model.dart';
import '../models/user_model.dart';

class DrinkProvider extends ChangeNotifier {
  UserModel? _user;
  List<DrinkEntry> _todayDrinks = [];

  static const double caffeineLimit = 400.0;
  static const double sugarLimit = 50.0;

  int get drinkStreakCount {
    return Hive.box('settings').get('drinkStreakCount', defaultValue: 0);
  }

  List<DrinkEntry> get todayDrinks => _todayDrinks;

  double get dailyCaffeine {
    return _todayDrinks.fold(0.0, (acc, item) => acc + item.caffeineAmount);
  }

  double get dailySugar {
    return _todayDrinks.fold(0.0, (acc, item) => acc + item.sugarAmount);
  }

  DrinkProvider() {
    initProvider();
  }

  Future<void> initProvider() async {
    var box = Hive.box<UserModel>('userBox');
    _user = box.get('currentUser');
    if (_user == null) return;

    _subscribeToTodayDrinks();
    notifyListeners();
  }

  // Mantıksal gün hesaplama (WaterProvider mantığı)
  String getLogicalDateKey([DateTime? forTime]) {
    final now = forTime ?? DateTime.now();
    final user = _user;
    if (user == null) return _formatDate(now);

    final parts = user.sleepTime.split(':');
    final sleepHour = int.parse(parts[0]);
    final sleepMinute = int.parse(parts[1]);



    final isSleepAfterMidnight = sleepHour < 6;

    if (isSleepAfterMidnight) {
      final prevDayToleranceEnd = DateTime(now.year, now.month, now.day, sleepHour, sleepMinute)
          .add(const Duration(hours: 2));
      if (now.isBefore(prevDayToleranceEnd)) {
        return _formatDate(now.subtract(const Duration(days: 1)));
      }
    } else {
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

  void _subscribeToTodayDrinks() {
    if (_user == null) return;
    final dateKey = getLogicalDateKey();
    
    // Firestore Path: users/{userId}/drinks/{dateKey}/entries
    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('drinks')
        .doc(dateKey)
        .collection('entries');

    collectionRef.snapshots().listen((snap) {
      _todayDrinks = snap.docs.map((doc) => DrinkEntry.fromMap(doc.data())).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('Firestore drinks stream error: $e');
    });
  }

  Future<void> addDrink(DrinkEntry entry) async {
    if (_user == null) return;
    
    final dateKey = getLogicalDateKey();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('drinks')
        .doc(dateKey)
        .collection('entries')
        .doc(entry.uid);

    await docRef.set(entry.toMap());
    _checkStreak();
  }

  void _checkStreak() {
    String lastDate = Hive.box('settings').get('lastDrinkStreakDate', defaultValue: '');
    String today = getLogicalDateKey();
    if (lastDate != today) {
      int current = drinkStreakCount;
      Hive.box('settings').put('drinkStreakCount', current + 1);
      Hive.box('settings').put('lastDrinkStreakDate', today);
    }
  }

  Future<void> deleteDrink(DrinkEntry entry) async {
    if (_user == null) return;

    final dateKey = getLogicalDateKey();
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('drinks')
        .doc(dateKey)
        .collection('entries')
        .doc(entry.uid);

    await docRef.delete();
  }

  // ─── İSTATİSTİK METODLARI ──────────────────────────────────────
  Future<Map<String, dynamic>> getWeeklyStats() async {
    if (_user == null) {
      return {'caffeineData': [], 'sugarData': [], 'types': {}, 'overLimitCount': 0, 'avgCaffeine': 0.0, 'avgSugar': 0.0, 'healthScore': 0};
    }

    final now = DateTime.now();
    List<double> caffeineData = [];
    List<double> sugarData = [];
    List<bool> consistency = [];
    Map<DrinkType, int> typeCounts = {};
    int overLimitCount = 0;

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dateKey = _formatDate(day);
      
      final snaps = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.firebaseId)
          .collection('drinks')
          .doc(dateKey)
          .collection('entries')
          .get();

      double dayCaffeine = 0;
      double daySugar = 0;

      for (var doc in snaps.docs) {
        final d = doc.data();
        dayCaffeine += (d['caffeineAmount'] as num?)?.toDouble() ?? 0;
        daySugar += (d['sugarAmount'] as num?)?.toDouble() ?? 0;
        
        final dt = DrinkType.values.firstWhere(
          (e) => e.name == d['drinkType'], 
          orElse: () => DrinkType.tea
        );
        typeCounts[dt] = (typeCounts[dt] ?? 0) + 1;
      }

      if (dayCaffeine > caffeineLimit || daySugar > sugarLimit) {
        overLimitCount++;
      }

      caffeineData.add(dayCaffeine);
      sugarData.add(daySugar);
      consistency.add(snaps.docs.isNotEmpty);
    }

    double totalCaffeine = caffeineData.fold(0.0, (a, b) => a + b);
    double totalSugar = sugarData.fold(0.0, (a, b) => a + b);
    double avgCaffeine = totalCaffeine / 7;
    double avgSugar = totalSugar / 7;
    int healthScore = ((7 - overLimitCount) / 7 * 100).round();

    return {
      'caffeineData': caffeineData,
      'sugarData': sugarData,
      'types': typeCounts,
      'overLimitCount': overLimitCount,
      'avgCaffeine': avgCaffeine,
      'avgSugar': avgSugar,
      'healthScore': healthScore,
      'consistency': consistency,
    };
  }

  Future<List<bool>> getWeeklyConsistency() async {
    if (_user == null) return List.filled(7, false);
    List<bool> result = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dateKey = _formatDate(day);

      final snaps = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.firebaseId)
          .collection('drinks')
          .doc(dateKey)
          .collection('entries')
          .limit(1)
          .get();

      result.add(snaps.docs.isNotEmpty);
    }
    return result;
  }

  Future<Set<DateTime>> getDrinkDays() async {
    if (_user == null) return {};
    Set<DateTime> days = {};
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      final dateKey = _formatDate(day);
      final snaps = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.firebaseId)
          .collection('drinks')
          .doc(dateKey)
          .collection('entries')
          .limit(1)
          .get();
      if (snaps.docs.isNotEmpty) {
        days.add(DateTime(day.year, day.month, day.day));
      }
    }
    return days;
  }

  Future<List<DrinkEntry>> getDrinkEntriesForDay(String dateKey) async {
    if (_user == null) return [];
    final snaps = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseId)
        .collection('drinks')
        .doc(dateKey)
        .collection('entries')
        .get();
    
    return snaps.docs.map((d) => DrinkEntry.fromMap(d.data())).toList();
  }
}

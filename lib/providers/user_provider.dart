import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> initUser() async {
    var box = Hive.box<UserModel>('userBox');
    if (box.isNotEmpty) {
      _currentUser = box.get('currentUser');
      notifyListeners();
    }
  }

  Future<bool> registerUser({
    required String name,
    required int age,
    required double weight,
    required String wakeUpTime,
    required String sleepTime,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. İsimden temiz bir ID üret (İnterneti beklemeyelim)
      final String cleanId = name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
      // Başına milisaniye ekleyelim ki "tamamen" benzersiz olsun (İnternet yokken kontrol edemeyiz)
      final String uniqueId = "${cleanId}_${DateTime.now().millisecondsSinceEpoch % 10000}";

      UserModel newUser = UserModel(
        displayName: name,
        firebaseId: uniqueId,
        age: age,
        weight: weight,
        wakeUpTime: wakeUpTime,
        sleepTime: sleepTime,
      );

      // 2. ÖNCE LOKALE (HIVE) KAYDET! (En garantisi budur)
      var box = Hive.box<UserModel>('userBox');
      await box.put('currentUser', newUser);
      _currentUser = newUser;

      // 3. Bildirimi hemen planla (Kayıt biter bitmez gelsin)
      NotificationService().scheduleNextReminder();

      // 4. FIREBASE'E ARKA PLANDA GÖNDERMEYİ DENE (Beklemeden - unawaited mantığı)
      // İnternet yoksa Firebase bunu 'offline' olarak kuyruğa alır
      unawaited(
        FirebaseFirestore.instance
            .collection('users')
            .doc(uniqueId)
            .set(newUser.toMap())
            .timeout(const Duration(seconds: 3))
            .catchError((e) => debugPrint("Firestore offline registration queue: $e"))
      );

      _isLoading = false;
      notifyListeners();
      return true; // Kullanıcı artık "Kayıtlı" sayılır
    } catch (e) {
      print("Kayıt Hatası (Kritik): $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser({
    required int age,
    required double weight,
    required String wakeUpTime,
    required String sleepTime,
  }) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      UserModel updatedUser = UserModel(
        displayName: _currentUser!.displayName,
        firebaseId: _currentUser!.firebaseId,
        age: age,
        weight: weight,
        wakeUpTime: wakeUpTime,
        sleepTime: sleepTime,
      );

      var box = Hive.box<UserModel>('userBox');
      await box.put('currentUser', updatedUser);
      _currentUser = updatedUser;

      unawaited(
        FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.firebaseId)
            .update(updatedUser.toMap())
            .timeout(const Duration(seconds: 3))
            .catchError((e) => debugPrint("Update sync deferred: $e"))
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print("Güncelleme Hatası: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

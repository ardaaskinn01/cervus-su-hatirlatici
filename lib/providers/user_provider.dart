import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> initUser() async {
    var box = Hive.box<UserModel>('userBox');
    if (box.isNotEmpty) {
      _currentUser = box.get('currentUser');
      if (_currentUser != null) {
        // Uygulama her açıldığında girişi kaydet
        recordVisit(_currentUser!.firebaseId);
      }
      notifyListeners();
    }
  }

  /// 🚀 Giriş Sayılarını Analiz Etme Sistemi
  /// Hem kullanıcı dökümanındaki 'enterCount'u artırır,
  /// hem de 'visits' alt koleksiyonuna detaylı döküman ekler.
  Future<void> recordVisit(String userId) async {
    try {
      final now = DateTime.now();
      // Döküman ID'si: Günün Tarihi + Saat (Unutulmaması için benzersizlik sağlar)
      // "2024-04-20_15-30-22" formatı
      final String docId = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      
      final String date = DateFormat('yyyy-MM-dd').format(now);
      final String time = DateFormat('HH:mm:ss').format(now);
      final String platform = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Other');
      
      // package_info_plus ile versiyonu dinamik alalım
      final packageInfo = await PackageInfo.fromPlatform();
      final String appVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

      // 1. Kullanıcı ana dökümanındaki toplam giriş sayısını artır
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'enterCount': FieldValue.increment(1)}, SetOptions(merge: true));

      // 2. 'visits' alt koleksiyonuna yeni giriş dökümanını ekle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('visits')
          .doc(docId)
          .set({
        'date': date,
        'time': time,
        'platform': platform,
        'appVersion': appVersion,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Giriş başarıyla kaydedildi: $docId");
    } catch (e) {
      debugPrint("❌ Giriş kaydı hatası: $e");
    }
  }

  // Bu fonksiyon Firebase'de benzersiz bir döküman adı bulana kadar döngüye girer!
  Future<String> _getUniqueFirebaseId(String baseName) async {
    // İsimden boşlukları silip küçük harfe çevirelim "Arda Askin" -> "ardaaskin"
    final cleanName = baseName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    String currentId = cleanName;
    int counter = 1;
    bool exists = true;

    while (exists) {
      // Firebase'den bu isimde biri var mı kontrol ediyoruz?
      var doc = await FirebaseFirestore.instance.collection('users').doc(currentId).get();
      if (!doc.exists) {
        exists = false;   // Yoksa, bu ID'yi kullanabiliriz.
        return currentId;
      } else {
        // Varsa yanına rakam ekleyip tekrar dene (arda1, arda2...)
        currentId = '$cleanName$counter';
        counter++;
      }
    }
    return currentId; 
  }

  Future<bool> registerUser({
    required String name,
    required int age,
    required double weight,
    required String wakeUpTime,
    required String sleepTime,
    bool isPrivacyAccepted = true, // Varsayılan true, onboarding'den geliyor
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Firebase Unique ID'yi bul (örn: "arda" veya "arda3")
      String uniqueId = await _getUniqueFirebaseId(name);

      // 2. Modeli oluştur. Ekranda saf ismi, Firebase arkaplanında benzersiz ID'yi tutuyoruz.
      UserModel newUser = UserModel(
        displayName: name,
        firebaseId: uniqueId,
        age: age,
        weight: weight,
        wakeUpTime: wakeUpTime,
        sleepTime: sleepTime,
        isPrivacyAccepted: isPrivacyAccepted,
      );

      // 3. Firebase'e kaydet (Unique ID doc name olarak)
      await FirebaseFirestore.instance.collection('users').doc(uniqueId).set(newUser.toMap());

      // 4. Lokale de (Hive) bu veriyi kaydet!
      var box = Hive.box<UserModel>('userBox');
      await box.put('currentUser', newUser);

      _currentUser = newUser;
      
      // İlk kayıtta da girişi işle
      await recordVisit(uniqueId);

      _isLoading = false;
      notifyListeners();
      return true; // Başarılı
    } catch (e) {
      print("Firebase veya Hive Kayıt Hatası: $e");
      _isLoading = false;
      notifyListeners();
      return false; // Başarısız
    }
  }

  Future<bool> updateUser({
    required String displayName,
    required int age,
    required double weight,
    required String wakeUpTime,
    required String sleepTime,
    int? customGoal,
  }) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Yeni verilerle modeli kopyala
      UserModel updatedUser = UserModel(
        displayName: displayName,
        firebaseId: _currentUser!.firebaseId,
        age: age,
        weight: weight,
        wakeUpTime: wakeUpTime,
        sleepTime: sleepTime,
        customGoal: customGoal,
      );

      // 2. Firestore'u güncelle
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.firebaseId)
          .update(updatedUser.toMap());

      // 3. Hive'ı güncelle
      var box = Hive.box<UserModel>('userBox');
      await box.put('currentUser', updatedUser);

      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print("Profil Güncelleme Hatası: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

}

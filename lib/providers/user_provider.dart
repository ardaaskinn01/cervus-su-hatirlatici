import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/dashboard_service.dart';

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
        // Merkezi Dashboard Senkronizasyonu (Sessizce)
        DashboardService().syncExistingUser(_currentUser!.firebaseId, _currentUser!.toMap());
        
        // 1. Uygulama her açıldığında girişi kaydet
        recordVisit(_currentUser!.firebaseId);
        // 2. Kullanıcıyı kendi özel konusuna (Topic) abone yap
        NotificationService().subscribeToUserTopic(_currentUser!.firebaseId);
      }
      notifyListeners();
    }
  }

  /// 🚀 Giriş Kayıt ve FCM Token Sistemi
  Future<void> recordVisit(String userId) async {
    try {
      final now = DateTime.now();
      final String docId = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
      // final String date = DateFormat('yyyy-MM-dd').format(now);
      // final String time = DateFormat('HH:mm:ss').format(now);
      final String platform = Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Other');
      
      final packageInfo = await PackageInfo.fromPlatform();
      final String appVersion = "${packageInfo.version}+${packageInfo.buildNumber}";

      // FCM Token'ı al
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("⚠️ FCM Token alınamadı: $e");
      }

      // Topic İsmini Hesapla (NotificationService'deki mantıkla aynı)
      final cleanId = userId.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
      final topicName = 'user_$cleanId';

      // 1. Kullanıcı ana dökümanını güncelle (giriş sayısı + FCM token + Topic)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'enterCount': FieldValue.increment(1),
        'fcmToken': fcmToken,
        'fcmTopic': topicName,         // Panelden bakmak için buraya kaydediyoruz
        'lastPlatform': platform,
        'lastAppVersion': appVersion,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. 'visits' dökümanını ARTIK ANA PROJEYE DEĞİL, DASHBOARD'A YAZIYORUZ 🚀
      await DashboardService().logVisit(
        userId: userId,
        visitId: docId,
        appVersion: appVersion,
        platform: platform,
      );

      /* Eski Sistem (Yedek olarak kalsın diye yorum satırı yapıldı)
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
      */

      debugPrint("✅ Giriş kaydedildi | FCM: ${fcmToken?.substring(0, 20)}...");
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
      
      // Merkezi Dashboard Senkronizasyonu
      DashboardService().syncExistingUser(uniqueId, newUser.toMap());

      // İlk kayıtta da girişi işle
      await recordVisit(uniqueId);

      _isLoading = false;
      notifyListeners();
      return true; // Başarılı
    } catch (e) {
      debugPrint("Firebase veya Hive Kayıt Hatası: $e");
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

      // Merkezi Dashboard Güncellemesi
      DashboardService().syncExistingUser(updatedUser.firebaseId, updatedUser.toMap());

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Profil Güncelleme Hatası: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

}

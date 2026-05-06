import 'dart:io';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DashboardService with WidgetsBindingObserver {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  FirebaseApp? _dashboardApp;
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Oturum takibi değişkenleri
  DateTime? _sessionStartTime;
  String? _currentUserId;
  String? _currentVisitId;
  int _totalSecondsThisSession = 0;
  Timer? _heartbeatTimer;

  Future<void> init() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    
    // Ana servisin (Default Firebase) tamamen ayağa kalktığından emin olmak için gecikme ekliyoruz
    await Future.delayed(const Duration(seconds: 2));

    try {
      // 🎯 YENİ PROJE BİLGİLERİ (dashboard-baf3f)
      _dashboardApp = Firebase.apps.any((app) => app.name == 'dashboard')
          ? Firebase.app('dashboard')
          : await Firebase.initializeApp(
              name: 'dashboard',
              options: const FirebaseOptions(
                apiKey: "AIzaSyBPOS5L2Qdoi0kVXgyQnCoWuAdbUfh_YAo",
                authDomain: "dashboard-baf3f.firebaseapp.com",
                projectId: "dashboard-baf3f",
                storageBucket: "dashboard-baf3f.firebasestorage.app",
                messagingSenderId: "607527844560",
                appId: "1:607527844560:web:2415525d9fa986fdc03cd5", // Web/Universal ID
                measurementId: "G-5CN9G1FZ0B",
              ),
            );

      _firestore = FirebaseFirestore.instanceFor(app: _dashboardApp!);
      _isInitialized = true;
      
      if (WidgetsBinding.instance.lifecycleState != null) {
        WidgetsBinding.instance.addObserver(this);
      } else {
        // Observers only work when the binding is fully set up
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addObserver(this);
        });
      }
      
      debugPrint('✅ Merkezi Dashboard Projesi Bağlandı (ID: dashboard-baf3f)');
    } catch (e) {
      debugPrint('❌ Dashboard Başlatma Hatası: $e');
    } finally {
      _isInitializing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _updateCurrentSessionDuration();
      _stopHeartbeat();
    } else if (state == AppLifecycleState.resumed) {
      _sessionStartTime = DateTime.now();
      _startHeartbeat();
    }
  }

  void startSession(String userId, String visitId) {
    _currentUserId = userId;
    _currentVisitId = visitId;
    _sessionStartTime = DateTime.now();
    _totalSecondsThisSession = 0;
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateCurrentSessionDuration();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _updateCurrentSessionDuration() async {
    if (_sessionStartTime == null || _currentUserId == null || _currentVisitId == null) return;

    final now = DateTime.now();
    final int elapsedSeconds = now.difference(_sessionStartTime!).inSeconds;
    _totalSecondsThisSession += elapsedSeconds;
    _sessionStartTime = now;

    try {
      await _firestore!
          .collection('users')
          .doc(_currentUserId)
          .collection('visits')
          .doc(_currentVisitId)
          .update({
        'durationSeconds': _totalSecondsThisSession,
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Süre Kaydı Hatası: $e');
    }
  }

  FirebaseFirestore? get firestore => _firestore;
  bool get isInitialized => _isInitialized;

  // SYNC METODU (Kullanıcı verilerini senkronize etmek için)
  Future<void> syncExistingUser(String userId, Map<dynamic, dynamic> userData) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      // Artık varlık kontrolü yapmadan set(merge: true) ile yazıyoruz ki güncellemeler de yansısın
      await _firestore!.collection('users').doc(userId).set({
        'originalName': userData['displayName'], // UserModel'den gelen
        'age': userData['age'],
        'registrationDate': userData['createdAt'] is String 
            ? Timestamp.fromDate(DateTime.parse(userData['createdAt']))
            : userData['createdAt'],
        'platform': Platform.isIOS ? 'iOS' : 'Android',
        'appId': 'drinkly',
        'isMigrated': true,
        'migratedAt': FieldValue.serverTimestamp(),
        'createdAt': userData['createdAt'] is String 
            ? Timestamp.fromDate(DateTime.parse(userData['createdAt']))
            : userData['createdAt'],
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Sync Hatası: $e');
    }
  }

  // 🚀 ZİYARET KAYIT METODU (Dashboard Projesine)
  Future<void> logVisit({
    required String userId,
    required String visitId,
    required String appVersion,
    required String platform,
  }) async {
    if (!_isInitialized || _firestore == null) return;

    try {
      final now = DateTime.now();
      final String date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final String time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('visits')
          .doc(visitId)
          .set({
        'date': date,
        'time': time,
        'platform': platform,
        'appVersion': appVersion,
        'timestamp': FieldValue.serverTimestamp(),
        'appId': 'drinkly', // Uygulama ayrımı için
      });
      
      // Oturumu başlat
      startSession(userId, visitId);
      
      debugPrint("📊 Dashboard'a giriş kaydedildi: $visitId");
    } catch (e) {
      debugPrint("⚠️ Dashboard Giriş Kaydı Hatası: $e");
    }
  }

}

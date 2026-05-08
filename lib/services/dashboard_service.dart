import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';


// ============================================================
// 🚀 DASHBOARD SERVICE — REST API MODU
// ============================================================
// Firebase.initializeApp(name:'dashboard') yerine doğrudan
// Firestore REST API kullanıyoruz. Bu sayede iOS'ta oluşan
// ikinci Firebase başlatma crash'i tamamen ortadan kalkıyor.
// ============================================================

class DashboardService with WidgetsBindingObserver {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  bool _isInitialized = false;

  // Dashboard projesi Firestore REST endpoint
  static const String _projectId = 'dashboard-baf3f';
  static final String _apiKey = dotenv.env['DASHBOARD_API_KEY'] ?? '';
  static final String _baseUrl =

      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  // Oturum takibi
  DateTime? _sessionStartTime;
  String? _currentUserId;
  String? _currentVisitId;
  int _totalSecondsThisSession = 0;
  Timer? _heartbeatTimer;

  // -----------------------------------------------------------
  // INIT
  // -----------------------------------------------------------
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addObserver(this);
    });

    debugPrint('✅ Dashboard Servisi hazır (REST API modu)');
  }

  // -----------------------------------------------------------
  // LIFECYCLE
  // -----------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _updateCurrentSessionDuration();
      _stopHeartbeat();
    } else if (state == AppLifecycleState.resumed) {
      _sessionStartTime = DateTime.now();
      _startHeartbeat();
    }
  }

  // -----------------------------------------------------------
  // SESSION
  // -----------------------------------------------------------
  void startSession(String userId, String visitId) {
    _currentUserId = userId;
    _currentVisitId = visitId;
    _sessionStartTime = DateTime.now();
    _totalSecondsThisSession = 0;
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _updateCurrentSessionDuration();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _updateCurrentSessionDuration() async {
    if (_sessionStartTime == null ||
        _currentUserId == null ||
        _currentVisitId == null) {
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_sessionStartTime!).inSeconds;
    _totalSecondsThisSession += elapsed;
    _sessionStartTime = now;

    await _patchDocument(
      'users/$_currentUserId/visits/$_currentVisitId',
      {
        'durationSeconds': {'integerValue': '$_totalSecondsThisSession'},
        'lastUpdate': {'timestampValue': now.toUtc().toIso8601String()},
      },
    );
  }

  // -----------------------------------------------------------
  // PUBLIC API
  // -----------------------------------------------------------

  /// Kullanıcı profil bilgilerini dashboard'a senkronize eder.
  Future<void> syncExistingUser(
      String userId, Map<dynamic, dynamic> userData) async {
    if (!_isInitialized) return;
    await _patchDocument('users/$userId', {
      'originalName': {'stringValue': userData['displayName']?.toString() ?? ''},
      'age': {'integerValue': '${userData['age'] ?? 0}'},
      'platform': {'stringValue': Platform.isIOS ? 'iOS' : 'Android'},
      'appId': {'stringValue': 'drinkly'},
      'isMigrated': {'booleanValue': true},
      'migratedAt': {
        'timestampValue': DateTime.now().toUtc().toIso8601String()
      },
    });
  }

  /// Ziyaret kaydeder ve oturumu başlatır.
  Future<void> logVisit({
    required String userId,
    required String visitId,
    required String appVersion,
    required String platform,
  }) async {
    if (!_isInitialized) return;

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final ok = await _setDocument('users/$userId/visits/$visitId', {
      'date': {'stringValue': date},
      'time': {'stringValue': time},
      'platform': {'stringValue': platform},
      'appVersion': {'stringValue': appVersion},
      'timestamp': {'timestampValue': now.toUtc().toIso8601String()},
      'appId': {'stringValue': 'drinkly'},
      'durationSeconds': {'integerValue': '0'},
    });

    if (ok) {
      startSession(userId, visitId);
      debugPrint("📊 Dashboard'a giriş kaydedildi: $visitId");
    }
  }

  bool get isInitialized => _isInitialized;

  // -----------------------------------------------------------
  // REST HELPERS
  // -----------------------------------------------------------

  /// Firestore REST: Belge yazar (override)
  Future<bool> _setDocument(
      String path, Map<String, dynamic> fields) async {
    try {
      final uri = Uri.parse('$_baseUrl/$path?key=$_apiKey');
      final body = jsonEncode({'fields': fields});
      final res = await http
          .patch(uri,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return true;
      debugPrint('⚠️ Dashboard set hata ${res.statusCode}: ${res.body}');
      return false;
    } catch (e) {
      debugPrint('⚠️ Dashboard set exception: $e');
      return false;
    }
  }

  /// Firestore REST: Belge günceller (PATCH)
  Future<void> _patchDocument(
      String path, Map<String, dynamic> fields) async {
    try {
      final updateMask =
          fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
      final uri =
          Uri.parse('$_baseUrl/$path?key=$_apiKey&$updateMask');
      final body = jsonEncode({'fields': fields});
      await http
          .patch(uri,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('⚠️ Dashboard patch exception: $e');
    }
  }
}

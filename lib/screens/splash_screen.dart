import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/dashboard_service.dart';
import 'onboarding_screen.dart';
import 'main_shell.dart';
import 'dart:async';

/// ==========================================
/// 🚀 ULTRA-SAFE SPLASH SCREEN (ZIRHLI MOD)
/// ==========================================
/// Uygulama açılır açılmaz UI render edilir.
/// Servisler (Firebase, AdMob) ARKA PLANDA başlar.
/// Hiçbir servis UI çizilmeli (Blue Screen) engellemez.
/// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isNavigated = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🌊 SPLASH: Başladı');

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.outOrdinary),
    );

    _controller.forward();

    // 🎯 KRİTİK: beklemeden servisleri tetikle!
    _startInitialization();
  }

  void _startInitialization() async {
    // 1. Ekranın çizilmesi için bekle (Hemen başlar başlamaz çizim yapılır)
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Maksimum bekleme süresi koy (Eğer her şey kilitlenirse bile 6 saniye sonra ana ekrana fırlat)
    Timer(const Duration(seconds: 6), () {
      if (mounted && !_isNavigated) {
        debugPrint('⏰ SPLASH TIMEOUT: Servisler bitmeden gidiyoruz.');
        _navigateToNext();
      }
    });

    try {
      // Firebase main.dart'ta başlatıldı, burada sadece bekliyoruz
      debugPrint('🔥 Firebase zaten hazır (main.dart’ta başlatıldı).');

      // Dashboard servisini Firebase hazır olduktan SONRA başlatıyoruz
      DashboardService().init();

      debugPrint('🔔 Bildirimler başlatılıyor...');
      await NotificationService().initialize();

      // 🌅 Günaydın bildirimi — her gün uyanış saati + 30dk (kullanıcı varsa)
      NotificationService().scheduleMorningGreeting();

      // 📅 Re-engagement bildirimleri — 3 ve 7 gün kullanılmadı uyarısı
      // Uygulama her açıldığında yeniden planlanır (süre sıfırlanır)
      NotificationService().scheduleReEngagementNotifications();

      // ⏰ Escalating su hatırlatıcıları — eğer son su kaydı varsa
      // (İlk açılış veya kullanıcı kayıtlı ise)
      final settingsBox = Hive.box('settings');
      final lastTs = settingsBox.get('lastWaterTimestamp');
      if (lastTs != null) {
        NotificationService().scheduleEscalatingReminders();
      }

      debugPrint('💰 AdMob başlatılıyor...');
      // initialize() zaten güvenli, ama beklemeden devam ediyoruz
      MobileAds.instance.initialize();

      // İşlemler biter bitmez yönlendir (Timer'ı bekleme)
      if (mounted && !_isNavigated) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await _checkVersionAndNavigate();
      }
    } catch (e) {
      debugPrint("⚠️ Servislerde hata: $e");
      if (mounted && !_isNavigated) await _checkVersionAndNavigate();
    }
  }

  Future<void> _checkVersionAndNavigate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      // 🎯 DRINKLY'NİN KENDİ FİRESTORE'UNA BAK (Default Firebase)
      // Koleksiyon: settings, Belge: app_config
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      
      if (doc.exists) {
        final latestInfo = doc.data();
        if (latestInfo != null) {
          final latestBuild = (latestInfo['latestBuildNumber'] as num?)?.toInt() ?? currentBuild;
          final iosUrl = latestInfo['iosUrl'] as String? ?? "";
          final androidUrl = latestInfo['androidUrl'] as String? ?? "";

          if (latestBuild > currentBuild) {
            if (mounted) {
              bool? continueToApp = await _showUpdateDialog(iosUrl, androidUrl);
              if (continueToApp == true) {
                _navigateToNext();
              }
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("⚠️ Versiyon kontrol hatası: $e");
    }
    
    _navigateToNext();
  }

  Future<bool?> _showUpdateDialog(String iosUrl, String androidUrl) {
    return showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Yeni Versiyon Hazır! 🚀'),
        content: const Text('Daha iyi bir deneyim için uygulamayı güncellemenizi öneririz.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Güncelleme'),
            onPressed: () => Navigator.pop(context, true),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final url = Platform.isIOS ? iosUrl : androidUrl;
              if (url.isNotEmpty) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _navigateToNext() {
    if (_isNavigated) return;
    _isNavigated = true;

    final userBox = Hive.box<UserModel>('userBox');
    final bool isRegistered = userBox.isNotEmpty && userBox.get('currentUser') != null;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          isRegistered ? const MainShell() : const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFF0EA5E9),
              Color(0xFF0EA5E9),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipOval(
                  child: Image.asset('assets/images/app_icon.png', width: 140, height: 140, fit: BoxFit.cover),
                ),
                const SizedBox(height: 30),
                const Text(
                  'DRINKLY',
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 8, color: Colors.white),
                ),
                const SizedBox(height: 50),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppCurves {
  static const Curve outOrdinary = Cubic(0.2, 0.0, 0.0, 1.0);
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/user_model.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../services/notification_service.dart';
import '../firebase_options.dart';
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
      // 3. Arka Plan Servisleri
      debugPrint('🔥 Firebase başlatılıyor...');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        debugPrint('🔥 Firebase başarıyla başlatıldı.');
      } else {
        debugPrint('🔥 Firebase zaten başlatılmış, atlanıyor.');
      }

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
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToNext();
      }
    } catch (e) {
      debugPrint("⚠️ Servislerde hata: $e");
      if (mounted && !_isNavigated) _navigateToNext();
    }
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/images/app_icon.png', width: 120, height: 120),
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

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

/// ==========================================
/// 🚀 ZERO-BLOCKING SPLASH SCREEN EKLENDİ
/// ==========================================
/// Geri kalan her şey (Firebase, AdMob, Bildirimler) 
/// Splash Screen içinde arka planda başlatılır.
/// Kullanıcı beyaz ekran görmez, SplashScreen'i ve yükleme ikonunu görür.
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

    // Arka planda servisleri başlat
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. İlk karenin çizilmesi için native motora zaman tanı
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // 2. FIREBASE BAŞLATMA 👇🎯 (En riskli nokta, try-catch içinde)
      debugPrint('🔥 Firebase başlatılıyor...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform
      ).timeout(const Duration(seconds: 10)); // Bekleme süresine kilit koyduk
      debugPrint('🔥 Firebase başarıyla başlatıldı.');

      // 3. BİLDİRİM SERVİS BAŞLATMA
      debugPrint('🔔 Bildirim servisi başlatılıyor...');
      await NotificationService().initialize().timeout(const Duration(seconds: 5));
      debugPrint('🔔 Bildirim servisi hazır.');

      // 4. ADMOB BAŞLATMA
      debugPrint('💰 Reklam servisi başlatılıyor...');
      MobileAds.instance.initialize();

      // En az 1-1.5 saniye splash kalsın, sonra yönlendir
      await Future.delayed(const Duration(milliseconds: 600));
      
      if (mounted) _navigateToNext();
    } catch (e) {
      debugPrint("⚠️ Başlatma sırasında hata (devam ediliyor): $e");
      // Hata olsa bile kullanıcıyı en azından uygulamaya sok
      if (mounted) _navigateToNext();
    }
  }

  void _navigateToNext() {
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
              Color(0xFFE1F5FE),
              Color(0xFF29B6F6),
              Color(0xFF0288D1),
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
                  child: const Icon(
                    Icons.water_drop_rounded,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'CERVUS',
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

// Custom Curve for smooth scaling
class AppCurves {
  static const Curve outOrdinary = Cubic(0.2, 0.0, 0.0, 1.0);
}

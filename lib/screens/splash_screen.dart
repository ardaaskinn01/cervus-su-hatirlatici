import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/user_model.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../services/notification_service.dart';
import '../firebase_options.dart';
import 'onboarding_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isInitStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitStarted) {
      _isInitStarted = true;
      _initializeApp();
    }
  }

  // ZAMAN AŞIMLI GÜVENLİ YÜKLEME 🛡️
  Future<void> _initializeApp() async {
    debugPrint('SPLASH: Guvenli yukleme baslatildi.');

    // 1. HIVE YÜKLEMESİ (Max 3 Saniye)
    try {
      await Future.any([
        _initHive(),
        Future.delayed(const Duration(seconds: 3), () => throw 'Hive Timeout')
      ]);
    } catch (e) {
      debugPrint('SPLASH WARNING: Hive kisminda sorun/gecikme: $e');
    }

    // Provider'ları hazırla
    if (mounted) {
      await context.read<UserProvider>().initUser().timeout(const Duration(seconds: 2)).catchError((_){});
    }

    // 2. FIREBASE YÜKLEMESİ (Max 5 Saniye) - iOS kilitlenmelerinin ana sebebi ⚠️
    try {
      debugPrint('SPLASH: Firebase bekleniyor...');
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 5));
      debugPrint('SPLASH: Firebase hazir.');
    } catch (e) {
      debugPrint('SPLASH ERROR: Firebase kilitlendi veya hata verdi, atlanıyor: $e');
    }

    // 3. DİĞER SERVİSLER (Fire and Forget)
    NotificationService().initialize();
    MobileAds.instance.initialize();

    // 4. NE OLURSA OLSUN YÖNLENDİR (Uygulama hapis kalmasın)
    _navigateToNext();
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    await Hive.openBox<UserModel>('userBox');
    await Hive.openBox('settings');
    await Hive.openBox('dailyData');
    await Hive.openBox('history');
  }

  void _navigateToNext() async {
    if (!mounted) return;
    
    // Hive acik mi kontrol et, acik degilse bile devam et (hata sayfasi yerine onboarding'e duser en azindan)
    bool isRegistered = false;
    try {
      final userBox = Hive.box<UserModel>('userBox');
      isRegistered = userBox.isNotEmpty && userBox.get('currentUser') != null;
    } catch (_) {}

    debugPrint('SPLASH: Final yonlendirme yapiliyor. Kayitli mi: $isRegistered');

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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE1F5FE), Color(0xFF29B6F6), Color(0xFF0288D1)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop_rounded, size: 100, color: Colors.white),
              const SizedBox(height: 30),
              const Text('CERVUS', style: TextStyle(
                fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 8, color: Colors.white,
              )),
              const SizedBox(height: 50),
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}

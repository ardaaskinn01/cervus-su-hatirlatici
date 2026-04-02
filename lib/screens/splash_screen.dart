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
    debugPrint('SPLASH: InitState basladi');
    
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Yüklemeyi sadece bir kere başlat (Rebuild'lerde tekrar etmesin)
    if (!_isInitStarted) {
      _isInitStarted = true;
      _initializeApp();
    }
  }

  // AĞIR YÜKLER BURADA ARKA PLANDA ÇALIŞIR
  Future<void> _initializeApp() async {
    debugPrint('SPLASH: Sistem yuklemeleri basliyor (Arka Plan)');

    // 1. HIVE
    try {
      debugPrint('STEP 1: Hive aciliyor');
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
      await Hive.openBox<UserModel>('userBox');
      await Hive.openBox('settings');
      await Hive.openBox('dailyData');
      await Hive.openBox('history');
      debugPrint('STEP 1: Hive Hazir');
    } catch (e) {
      debugPrint('ERR: Hive hatasi: $e');
    }

    // LocaleProvider ve UserProvider'i manuel tetikle (Hive'dan verileri okusunlar)
    if (mounted) {
      await context.read<UserProvider>().initUser();
    }

    // 2. FIREBASE (iOS'ta kitlenmeye sebep olan yer burasi olabilir, SplashScreen icinde olmali!)
    try {
      debugPrint('STEP 2: Firebase config basliyor');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        debugPrint('STEP 2: Firebase Basariyla Yuklendi');
      }
    } catch (e) {
      debugPrint('ERR: Firebase hatasi: $e');
    }

    // 3. DIGER SERVISLER (Non-blocking)
    debugPrint('STEP 3: Diger servisler tetikleniyor');
    NotificationService().initialize();
    MobileAds.instance.initialize();

    // 4. SON OLARAK YÖNLENDİR
    _navigateToNext();
  }

  void _navigateToNext() async {
    debugPrint('SPLASH: Yonlendirme yapiliyor');
    if (!mounted) return;

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
    debugPrint('SPLASH: Build calisti');
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

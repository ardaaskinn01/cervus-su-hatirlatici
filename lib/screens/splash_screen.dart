import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../providers/water_provider.dart';
import '../providers/locale_provider.dart';
import '../services/notification_service.dart';
import 'onboarding_screen.dart';
import 'main_shell.dart';

/// ==========================================================
/// 🌊 SPLASH SCREEN - Zırhlı Yükleme Katmanı
/// ==========================================================
/// Kullanıcı mavi gradyanlı splash ekranı görürken,
/// arka planda TÜM ağır servisler yüklenir.
/// Yükleme bitmeden kesinlikle navigasyon yapılmaz.
/// ==========================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isInitialized = false;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🌊 SPLASH: initState başladı');

    // 1. Animasyon Hazırlığı
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

    // 2. Arka Planda Tüm Servisleri Başlat
    _initializeServices();
  }

  /// Tüm servisleri sırayla başlatır, sonra state günceller.
  Future<void> _initializeServices() async {
    debugPrint('🌊 SPLASH: Sistem yüklemeleri başlıyor (Arka Plan)');

    // ─── ADIM 1: HIVE (Lokal Veritabanı) ──────────────────────
    try {
      debugPrint('📦 STEP 1: Hive açılıyor...');
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(UserModelAdapter());
      }
      await Hive.openBox<UserModel>('userBox');
      await Hive.openBox('settings');
      await Hive.openBox('dailyData');
      await Hive.openBox('history');
      debugPrint('📦 STEP 1: Hive Hazır ✅');

      // Kayıtlı kullanıcı var mı kontrol et
      final userBox = Hive.box<UserModel>('userBox');
      _isRegistered = userBox.isNotEmpty && userBox.get('currentUser') != null;
      debugPrint('👤 Kullanıcı durumu: ${_isRegistered ? "Kayıtlı" : "Yeni"}');
    } catch (e) {
      debugPrint('⚠️ Hive hatası: $e');
    }

    // ─── ADIM 2: FIREBASE ──────────────────────────────────────
    try {
      debugPrint('🔥 STEP 2: Firebase başlatılıyor...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⚠️ Firebase zaman aşımı! Devam ediliyor...');
          return Firebase.app();
        },
      );
      debugPrint('🔥 STEP 2: Firebase Hazır ✅');
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        debugPrint('🔥 Firebase zaten başlatılmış, devam ediliyor.');
      } else {
        debugPrint('⚠️ Firebase hatası: $e - Devam ediliyor...');
      }
    }

    // ─── ADIM 3: BİLDİRİM SERVİSİ ─────────────────────────────
    try {
      debugPrint('🔔 STEP 3: Bildirim servisi başlatılıyor...');
      await NotificationService().initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Bildirim servisi zaman aşımı! Devam ediliyor...');
        },
      );
      debugPrint('🔔 STEP 3: Bildirim servisi Hazır ✅');
    } catch (e) {
      debugPrint('⚠️ Bildirim hatası: $e - Devam ediliyor...');
    }

    // ─── ADIM 4: REKLAMLAR (Arka Plan - Beklemeden!) ────────────
    debugPrint('💰 STEP 4: Reklamlar tetikleniyor (arka plan)...');
    MobileAds.instance.initialize().then((status) {
      debugPrint('💰 Reklam servisi hazır: $status');
    }).catchError((e) {
      debugPrint('⚠️ Reklam hatası: $e');
    });

    // ─── ADIM 5: MİNİMUM 2 SANİYE SPLASH GÖSTERİMİ ────────────
    await Future.delayed(const Duration(seconds: 2));

    // ─── ADIM 6: STATE GÜNCELLE VE YÖNLENDİR ──────────────────
    if (!mounted) return;
    debugPrint('🌊 SPLASH: Yükleme tamamlandı, yönlendirme yapılıyor...');

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yükleme tamamlandıysa provider'lı uygulamaya geç
    if (_isInitialized) {
      debugPrint('🌊 SPLASH: Provider\'lı uygulama oluşturuluyor');
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            var userProvider = UserProvider();
            userProvider.initUser();
            return userProvider;
          }),
          ChangeNotifierProvider(create: (_) => WaterProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: Consumer<LocaleProvider>(
          builder: (context, localeProvider, child) {
            return MaterialApp(
              title: 'Cervus Su Hatırlatıcı',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                primaryColor: const Color(0xFF29B6F6),
                scaffoldBackgroundColor: const Color(0xFFF4F9F9),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF29B6F6),
                  primary: const Color(0xFF29B6F6),
                  secondary: const Color(0xFF4DD0E1),
                  surface: Colors.white,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF29B6F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                ),
              ),
              home: _isRegistered ? const MainShell() : const OnboardingScreen(),
            );
          },
        ),
      );
    }

    // Yükleme devam ediyorken splash ekranı göster
    return Scaffold(
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
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
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: Colors.white,
                    fontFamily: 'Roboto',
                  ),
                ),
                const Text(
                  'SU HATIRLATICI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                    color: Colors.white70,
                  ),
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

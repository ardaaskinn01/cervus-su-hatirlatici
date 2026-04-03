import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

/// ==========================================================
/// 🚀 SIFIR ENGELLEME BAŞLATMA (Non-Blocking Startup)
/// ==========================================================
/// main() içinde HİÇBİR await yok!
/// iOS, uygulamayı anında "açılmış" kabul eder.
/// Tüm ağır yükler (Firebase, Hive, FCM, Ads) SplashScreen
/// içinde arka planda yüklenir.
/// ==========================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 START: main() çalıştı - runApp anında çağrılıyor');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🚀 STEP: MyApp.build() - SplashScreen gösteriliyor');
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
      home: const SplashScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';

import 'models/user_model.dart';
import 'providers/user_provider.dart';
import 'providers/water_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  // 1. ANINDA BAŞLAT ✅🎯
  WidgetsFlutterBinding.ensureInitialized();

  // 2. HIVE (Kritik - Uygulama için gerekli veriler burada)
  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    await Hive.openBox<UserModel>('userBox');
    await Hive.openBox('settings');
    await Hive.openBox('dailyData');
    await Hive.openBox('history');
  } catch (e) {
    debugPrint('⚠️ Hive Kutsal Emanetleri Açılamadı: $e');
  }

  // 3. SERVİSLERİ ARKA PLANDA BAŞLAT (Uygulamayı bekleme noktasına sokma!) 👇🚀
  // Bir saniyelik gecikme ile veriyoruz ki uygulama önce bir "kendine gelsin" ✅🎯
  Future.delayed(const Duration(seconds: 2), () {
    _fireAndForgetServices();
  });

  // 4. UYGULAMAYI ANINDA ÇALIŞTIR ✅🏆🥇
  runApp(const MyApp());
}

// Servisleri sessizce (unawaited) arkada başlatır 😉🚀🦾
void _fireAndForgetServices() {
  Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).then((_) {
    NotificationService().initialize();
    MobileAds.instance.initialize();
    debugPrint('🔥 Firebase ve Servisler Arka Planda Hazırlandı.');
  }).catchError((e) => debugPrint('⚠️ Servis Başlatma Hatası: $e'));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🛡️ MaterialApp'i Provider'ların DIŞINA veya Hemen İçine Alalım 
    // Ama Provider'dan bir değişken (Consumer) bekleyerek kilitlemeyelim. ✅🎯
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
           final up = UserProvider();
           up.initUser(); // Unawaited init
           return up;
        }),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
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
        // Her zaman SplashScreen ile başla. (Beyaz ekranın antitezi budur!) ✅🎯🏆🥇
        home: const SplashScreen(),
      ),
    );
  }
}

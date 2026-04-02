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
  WidgetsFlutterBinding.ensureInitialized();

  // 1. HIVE - Lokal veri (hızlı, await edilebilir)
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
    debugPrint('⚠️ Hive açılamadı: $e');
  }

  // 2. FIREBASE - await ile başlat (UserProvider ve NotificationService buna bağımlı!)
  // Bu olmadan Firestore çağrıları crash yapar.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🔥 Firebase hazır.');
  } catch (e) {
    debugPrint('⚠️ Firebase başlatılamadı: $e');
  }

  // 3. ADMOB & BİLDİRİMLER - fire and forget (Firebase'i beklemezler ama içinde kullanabilirler)
  _startSecondaryServices();

  // 4. UYGULAMAYI BAŞLAT
  runApp(const MyApp());
}

void _startSecondaryServices() {
  NotificationService().initialize();
  MobileAds.instance.initialize();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final up = UserProvider();
          up.initUser();
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
        home: const SplashScreen(),
      ),
    );
  }
}

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
  // 1. MOTORU UYANDIR (Beyaz ekran kalkanı)
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('➡️ STARTUP: Motor uyandi');

  // 2. YEREL VERİTABANI (Milisaniyeler sürer)
  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    await Hive.openBox<UserModel>('userBox');
    await Hive.openBox('settings');
    await Hive.openBox('dailyData');
    await Hive.openBox('history');
  } catch (e) {
    debugPrint('⚠️ Hive Hatası: $e');
  }

  // 3. AĞIR SERVİSLERİ ARKA PLANDA BAŞLAT (Asla await etme!)
  _initSlowServices();

  // 4. DİL YAPILANDIRMASI
  final localeProvider = LocaleProvider(); 

  // 5. UYGULAMAYI ATEŞLE
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
           final up = UserProvider();
           up.initUser(); 
           return up;
        }),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider.value(value: localeProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cervus Su Hatırlatıcı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF29B6F6),
        scaffoldBackgroundColor: const Color(0xFFF4F9F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF29B6F6),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// 🛡️ FIREBASE KİLİTLENMELERİNE KARŞI ARKA PLAN BAŞLATICI
void _initSlowServices() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    NotificationService().initialize();
    MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('⚠️ Servis Başlatma Hatası: $e');
  }
}

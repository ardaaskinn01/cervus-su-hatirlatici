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
  // 1. MOTORU UYANDIR (Beyaz ekran kalkanı 1)
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('➡️ STARTUP: Motor uyandi');

  // 2. YEREL VERITABANI VE YAPILANDIRMA (Isik hizinda biter)
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

  // 3. FIREBASE BASLAT (iOS APNs takilmasini engellemek icin await etsek de arkasini saglama alacagiz)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint('⚠️ Firebase Hatasi: $e');
  }

  // 4. SERVISLERI BASLAT (Fire-and-forget: Aninda dondurur, startup'i bloklamaz)
  NotificationService().initialize();
  MobileAds.instance.initialize();

  // 5. DIK DIKKAT: Dil Provider'ini disarida olusturuyoruz ki runApp icinde "Re-entrant build" (Sonsuz Dongu Beyaz Ekrani) yapmasin.
  final localeProvider = LocaleProvider(); 
  
  // 6. UYGULAMAYI ANINDA GOSTER (Splash Screen 2 saniye isler)
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

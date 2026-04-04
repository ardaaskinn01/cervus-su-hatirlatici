import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'models/user_model.dart';
import 'providers/user_provider.dart';
import 'providers/water_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

/// ==========================================================
/// 🚀 ZERO-BLOCKING STARTUP (ZORLU ALARM MODELİ)
/// ==========================================================
/// main() içerisinde HİÇBİR ağır işlem (Firebase, FCM vb.) 
/// BEKLENMEZ. Bu sayede iOS Beyaz Ekran hatası kesinlikle çözülür.
/// ==========================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 main() başladı');
  
  // 1. Sadece Hive'ı (Veritabanı) başlatıyoruz (Hızlıdır, kilitlenme yapmaz)
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
  
  await Hive.openBox<UserModel>('userBox');
  await Hive.openBox('settings');
  await Hive.openBox('dailyData');
  await Hive.openBox('history');
  debugPrint('📦 Hive hazır');

  // 2. Uygulamayı anında başlatıyoruz
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

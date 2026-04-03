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
  // 🛡️ İlk kareyi koru: Flutter motorunu uyandır.
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('➡️ START: main() basladi');

  // 🛡️ ÇOK HIZLI İŞLEMLER (Yerel Veri): SplashScreen'in düzgün çizilmesi için gereklidir.
  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    await Hive.openBox<UserModel>('userBox');
    await Hive.openBox('settings');
    await Hive.openBox('dailyData');
    await Hive.openBox('history');
    debugPrint('➡️ STEP 1: Hive Hazir');
  } catch (e) {
    debugPrint('⚠️ Hive Hatası: $e');
  }

  // 🛡️ DİL DOSYALARI (Çok Hızlı): SplashScreen'deki metinlerin anında görünmesini sağlar.
  final localeProvider = LocaleProvider(); 
  // Initializer içinde dil yüklemesi zaten yapılıyor.

  // 🛡️ UYGULAMAYI ANINDA ÇALIŞTIR (Firebase'i beklemeden!)
  debugPrint('➡️ STEP 2: runApp() Cagriliyor');
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

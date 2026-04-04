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

/// ==========================================================
/// 🚀 ABSOLUTE ZERO-BLOCKING STARTUP (ZIRHLI MOD V2)
/// Eğer main() içerisinde Hive patlarsa, runApp() hiç çağrılmaz
/// ve uygulama SONSUZA KADAR BEYAZ EKRANDA kalır.
/// Bu yüzden main() devasa bir try-catch ile korunmalıdır!
/// ==========================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 main() başladı');
  
  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    
    // Hive bazen sürüm/model değişimlerinde crash atabilir. 
    // Eğer TestFlight'ta eski sürüm yüklüyse ve model değiştiyse, 
    // openBox anında patlayıp uygulamayı beyaz ekrana gömer.
    await Hive.openBox<UserModel>('userBox');
    await Hive.openBox('settings');
    await Hive.openBox('dailyData');
    await Hive.openBox('history');
    debugPrint('📦 Hive hazır');
  } catch (e) {
    debugPrint('🚨 KRITIK HATA: Hive kutuları açılamadı! Temizleniyor... Hata: $e');
    // Eğer kutular bozuksa silip sıfırdan açalım ki beyaz ekran kalksın
    try {
      await Hive.deleteBoxFromDisk('userBox');
      await Hive.deleteBoxFromDisk('settings');
      await Hive.deleteBoxFromDisk('dailyData');
      await Hive.deleteBoxFromDisk('history');
      await Hive.openBox<UserModel>('userBox');
    } catch (e2) {
      debugPrint('🚨 FATAL: Hive tamamen çöktü: $e2');
    }
  }

  // Hata Ekranı Yakalayıcı (BEYAZ EKRAN YERİNE HATAYI GÖSTER) 👇
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.red.shade900,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️ UYGULAMA ÇÖKTÜ:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(details.exceptionAsString(), style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 10),
              Text(details.stack?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  };

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
          // Eğer initUser içinde Hive patlarsa diye onu provider içinde koruyoruz.
          try {
            userProvider.initUser();
          } catch(e) { debugPrint("UserProvider init hatası: $e"); }
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

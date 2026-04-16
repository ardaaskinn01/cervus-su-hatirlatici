import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  
    // Tarih formatlama yerelleştirmesini garantiye alalım (Hereden bağımsız)
    await initializeDateFormatting('tr_TR', null);
    await initializeDateFormatting('en_US', null);
    
    debugPrint('🔧 Servisler başlatılıyor...');
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await MobileAds.instance.initialize();
      debugPrint('✅ Servisler hazır');
    } catch (e) {
      debugPrint('⚠️ Servis başlatma uyarısı (Bazı özellikler çalışmayabilir): $e');
    }

  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 60),
                const SizedBox(height: 16),
                const Text('⚠️ UYGULAMA ÇÖKTÜ:', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Text(details.exceptionAsString(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                const Text('STACK TRACE:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(details.stack?.toString() ?? 'No stack trace available', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
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
            title: 'Drinkly',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              primaryColor: const Color(0xFF0EA5E9),
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0EA5E9),
                primary: const Color(0xFF0EA5E9),
                secondary: const Color(0xFF38BDF8),
                surface: Colors.white,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0EA5E9),
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

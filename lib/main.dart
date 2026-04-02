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

void main() {
  // Emojisiz net takip logları
  debugPrint('START: main() calisti');
  
  // 1. Flutter engine'i anında uyandır
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('STEP 1: WidgetsFlutterBinding hazır');

  // 2. Uygulamayı BEKLETMEDEN başlat (Beyaz ekranı engellemenin yolu budur)
  // Ağır yükleri (Firebase/Hive) SplashScreen icinde veya runApp'ten sonra cagiracagiz.
  debugPrint('STEP 2: runApp() cagriliyor (Bekleme yapilmiyor)');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
        title: 'Cervus Su Hatırlatıcı',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: const Color(0xFF29B6F6),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF29B6F6),
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
        ),
        // SplashScreen artik sadece gorsel degil, yukleyici gorevi gorecek.
        home: const SplashScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'models/user_model.dart';
import 'providers/user_provider.dart';
import 'providers/water_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

// ─── BİLDİRİM EYLEM DİNLEYİCİSİ (TOP-LEVEL) ───────────────────────────
/*
@pragma("vm:entry-point")
Future<void> onActionReceivedMethod(dynamic receivedAction) async {
  // Sadece su ekleme butonlarına basıldıysa devreye gir
  if (receivedAction.buttonKeyPressed == 'ADD_100' || receivedAction.buttonKeyPressed == 'ADD_200') {
    
    // İzole edilmiş (Isolate) bir bellekte olduğumuz için her şeyi manuel başlatmalıyız
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
    
    final userBox = await Hive.openBox<UserModel>('userBox');
    final user = userBox.get('currentUser');
    if (user == null) return;

    int amount = receivedAction.buttonKeyPressed == 'ADD_100' ? 100 : 200;

    // Mantıksal günü hesaplayalım
    final now = DateTime.now();
    final dateKey = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final saat = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // 🔥 FIREBASE KAYDI
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.firebaseId)
        .collection('gunler')
        .doc(dateKey);

    await docRef.set({
      'gunlukMiktar': FieldValue.increment(amount),
      'suIcildi': FieldValue.arrayUnion([{
        'uid': DateTime.now().millisecondsSinceEpoch.toString(),
        'saat': saat, 
        'miktar': amount
      }]),
    }, SetOptions(merge: true));

    // Yeni bildirimi kur (Tekrar döngüsünü başlat)
    await NotificationService().scheduleNextReminder();
  }
}
*/

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {}

  MobileAds.instance.initialize();
  
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserModelAdapter());
  
  await Hive.openBox<UserModel>('userBox');
  await Hive.openBox('settings');
  await Hive.openBox('dailyData');
  await Hive.openBox('history');
  
  await NotificationService().initialize();

  // Dinleyiciyi üst seviye fonksiyona bağla
  /*
  AwesomeNotifications().setListeners(
    onActionReceivedMethod: onActionReceivedMethod,
  );
  */

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isRegistered = Hive.box<UserModel>('userBox').isNotEmpty;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          var userProvider = UserProvider();
          userProvider.initUser();
          return userProvider;
        }),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
      ],
      child: MaterialApp(
        title: 'Su Hatırlatıcı',
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
        home: isRegistered ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}

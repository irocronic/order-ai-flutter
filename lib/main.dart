// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:makarna_app/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';

// Zaman dilimi için importlar
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// Ortam Değişkenleri ve Servisler
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/connectivity_service.dart';
import 'services/cache_service.dart';
import 'services/sync_service.dart';
import 'services/global_notification_handler.dart';
import 'models/sync_queue_item.dart';
import 'models/printer_config.dart';

// Native Splash importu
import 'package:flutter_native_splash/flutter_native_splash.dart';

// Yerelleştirme
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Provider
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';

// Uygulama İçi Satın Alma
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

// Platform Kontrolü
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

// Global Keys
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<dynamic>> routeObserver = RouteObserver<ModalRoute<dynamic>>();

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();
  Hive.registerAdapter(SyncQueueItemAdapter());
  Hive.registerAdapter(PrinterConfigAdapter());

  // Servisleri başlat
  await CacheService.instance.initialize();
  ConnectivityService.instance.initialize();
  SyncService.instance.initialize();

  // Zaman dilimini ayarla
  tz.initializeTimeZones();
  try {
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    print("Zaman dilimi alınamadı: $e");
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  }

  // Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Uygulamayı çalıştır
  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..loadLocale(),
      child: const MyApp(),
    ),
  );

  // Uygulama genelindeki bildirim dinleyicisini başlat.
  GlobalNotificationHandler.initialize();

  // Splash screen'i kaldır
  await Future.delayed(const Duration(seconds: 1));
  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      title: 'OrderAI',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      locale: languageProvider.currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', ''),
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
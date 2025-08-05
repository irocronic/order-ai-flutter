// lib/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../services/user_session.dart';
import 'login_screen.dart';
// DEĞİŞİKLİK: Silinen app_shell.dart yerine business_owner_home.dart import edildi
import 'business_owner_home.dart';
import 'admin_home.dart';
import 'setup_wizard_screen.dart';
import 'subscription_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    final token = UserSession.token;

    if (token.isEmpty) {
      debugPrint("[SplashScreen] Token bulunamadı. Login ekranına yönlendiriliyor.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    bool isTokenExpired = true;  
    try {
      isTokenExpired = JwtDecoder.isExpired(token);
    } catch (e) {
      debugPrint("[SplashScreen] Token parse edilemedi, geçersiz kabul ediliyor: $e");
      isTokenExpired = true;  
    }
    
    if (isTokenExpired) {
      debugPrint("[SplashScreen] Token süresi dolmuş. Login ekranına yönlendiriliyor.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final userType = UserSession.userType;
    final businessId = UserSession.businessId;
    final isSetupComplete = UserSession.isSetupComplete;
    final subscriptionStatus = UserSession.subscriptionStatus;

    debugPrint("[SplashScreen] Geçerli token bulundu. Kullanıcı tipi: $userType, İşletme ID: $businessId, Kurulum tamamlandı mı: $isSetupComplete, Abonelik Durumu: $subscriptionStatus");

    // Yönlendirme mantığı
    if (userType == 'business_owner' || userType == 'staff' || userType == 'kitchen_staff') {
        if (businessId == null) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        } else if (userType == 'business_owner' && (subscriptionStatus == 'inactive' || subscriptionStatus == 'cancelled')) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
        } else if (userType == 'business_owner' && !isSetupComplete) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SetupWizardScreen(token: token, businessId: businessId)));
        } else {
            // *** DEĞİŞİKLİK BURADA: Artık BusinessOwnerHome'a yönlendiriyoruz ***
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BusinessOwnerHome(token: token, businessId: businessId)));
        }
    } else if (userType == 'admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminHome(token: token)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandTextStyle = TextStyle(
      fontSize: 60.0,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1), // blue.shade900
      body: Center(
        child: AnimatedTextKit(
          animatedTexts: [
            FadeAnimatedText(
              'OrderAI',
              textStyle: brandTextStyle,
              duration: const Duration(seconds: 4),
            ),
          ],
          totalRepeatCount: 1,  
          onFinished: () {
            _navigateToNextScreen();
          },
        ),
      ),
    );
  }
}
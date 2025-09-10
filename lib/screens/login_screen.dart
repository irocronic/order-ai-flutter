// lib/screens/login_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/user_session.dart';
import '../services/global_notification_handler.dart';
import 'business_owner_home.dart';
import 'admin_home.dart';
import 'register_screen.dart';
import 'setup_wizard_screen.dart';
import 'password_reset_request_screen.dart';
import 'subscription_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessageKey = '';
  bool _isLoading = false;
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _errorMessageKey = '';
    });
    
    try {
      final data = await ApiService.login(
          _usernameController.text.trim(), _passwordController.text.trim());
      
      await UserSession.storeLoginData(data);

      // 🔧 FIX 3: Login sonrası doğru sıralama
      // 🆕 CRITICAL: İkinci bir güvence daha ekleyelim
      SocketService.allowInitialization();
      debugPrint('[LoginScreen] SocketService initialization allowed after login');
      
      // 🆕 CRITICAL: Kısa bir delay ekle ki önceki bağlantılar tamamen temizlensin
      await Future.delayed(const Duration(milliseconds: 800)); // 500ms'den 800ms'ye çıkarıldı
      
      // GlobalNotificationHandler yeniden başlat
      GlobalNotificationHandler.initialize();
      debugPrint('[LoginScreen] GlobalNotificationHandler initialized after login');

      if (!mounted) return;
      
      final userType = UserSession.userType;
      final businessId = UserSession.businessId;
      final isSetupComplete = UserSession.isSetupComplete;
      final subscriptionStatus = UserSession.subscriptionStatus;
      
      if (userType == 'business_owner') {
        if (businessId == null) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        } else if (subscriptionStatus == 'inactive' || subscriptionStatus == 'cancelled') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
        } else if (!isSetupComplete) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SetupWizardScreen(token: UserSession.token, businessId: businessId)));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BusinessOwnerHome(token: UserSession.token, businessId: businessId)));
        }
      } else if (userType == 'staff' || userType == 'kitchen_staff') {
        if (businessId != null) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => BusinessOwnerHome(token: UserSession.token, businessId: businessId)));
        } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      } else if (userType == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminHome(token: UserSession.token)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }

    } catch (e) {
      debugPrint('[LoginScreen] Login error: $e');
      if (mounted) {
        String errorKey = 'loginErrorInvalidCredentials';
        String exceptionString = e.toString().toLowerCase();

        if (exceptionString.contains('no_shift_scheduled') || exceptionString.contains('no_shift_assigned') || exceptionString.contains('no_active_shift_at_login')) {
          errorKey = 'loginErrorNoActiveShift';
        }
        else if (exceptionString.contains("account_not_approved")) {
          errorKey = 'loginErrorAccountNotApproved';
        } else if (exceptionString.contains("account_inactive")) {
          errorKey = 'loginErrorAccountInactive';
        } else if (exceptionString.contains("subscription_expired")) {
          errorKey = 'loginErrorSubscriptionExpired';
        }
        
        setState(() {
          _errorMessageKey = errorKey;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String errorMessageText = '';

    if (_errorMessageKey.isNotEmpty) {
      switch (_errorMessageKey) {
        case 'loginErrorNoActiveShift':
          errorMessageText = l10n.loginErrorNoActiveShift;
          break;
        case 'loginErrorInvalidCredentials':
          errorMessageText = l10n.loginErrorInvalidCredentials;
          break;
        case 'loginErrorAccountInactive':
          errorMessageText = l10n.loginErrorAccountInactive;
          break;
        case 'loginErrorAccountNotApproved':
          errorMessageText = l10n.loginErrorAccountNotApproved;
          break;
        case 'loginErrorSubscriptionExpired':
          errorMessageText = l10n.loginErrorSubscriptionExpired;
          break;
        default:
          errorMessageText = l10n.loginErrorInvalidCredentials;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.loginPageTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade900, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade900.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.white.withOpacity(0.85),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: l10n.usernameLabel,
                              labelStyle: const TextStyle(color: Colors.black54),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.7),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade600),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.usernameHint;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: l10n.passwordLabel,
                              labelStyle: const TextStyle(color: Colors.black54),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.7),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return l10n.passwordHint;
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordResetRequestScreen()));
                                    },
                              child: Text(
                                l10n.forgotPasswordButtonText,
                                style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : Text(l10n.loginButtonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                side: BorderSide(color: Colors.blue.shade800.withOpacity(0.9), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                backgroundColor: Colors.white.withOpacity(0.75),
                                foregroundColor: Colors.blue.shade900,
                              ),
                              child: Text(
                                l10n.registerPromptText,
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                              ),
                            ),
                          ),
                          if (errorMessageText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                errorMessageText,
                                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
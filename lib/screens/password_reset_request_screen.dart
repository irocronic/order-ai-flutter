// lib/screens/password_reset_request_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/api_service.dart'; // ApiService importu
import 'password_reset_confirm_screen.dart'; // Yeni şifre girme ekranı

class PasswordResetRequestScreen extends StatefulWidget {
  const PasswordResetRequestScreen({Key? key}) : super(key: key);

  @override
  _PasswordResetRequestScreenState createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends State<PasswordResetRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String _message = '';
  Color _messageColor = Colors.redAccent;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      await ApiService.requestPasswordReset(_emailController.text.trim());
      if (mounted) {
        setState(() {
          _message = l10n.passwordResetSuccessMessage;
          _messageColor = Colors.green;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message), backgroundColor: _messageColor, duration: const Duration(seconds: 4)),
        );
        await Future.delayed(const Duration(seconds: 1));
        if(mounted) {
          // Kullanıcıyı kodu gireceği ekrana yönlendir, e-postayı da parametre olarak geçir.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PasswordResetConfirmScreen(email: _emailController.text.trim()),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = e.toString().replaceFirst("Exception: ", "");
          _messageColor = Colors.redAccent;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.passwordResetTitle, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
        child: Center(
          // --- DEĞİŞİKLİK BURADA BAŞLIYOR ---
          // Geniş ekranlarda formun yayılmasını önlemek için ConstrainedBox eklendi.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.white.withOpacity(0.85),
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.passwordResetInstruction,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: l10n.emailLabel,
                            labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade600),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.emailHintRequired;
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                              return l10n.emailHintInvalid;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _sendResetRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Text(l10n.passwordResetSendCodeButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        if (_message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(
                              _message,
                              style: TextStyle(color: _messageColor, fontWeight: FontWeight.bold),
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
          // --- DEĞİŞİKLİK BURADA BİTİYOR ---
        ),
      ),
    );
  }
}
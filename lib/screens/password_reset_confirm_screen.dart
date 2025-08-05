// lib/screens/password_reset_confirm_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'login_screen.dart'; // Başarılı sıfırlama sonrası login ekranına yönlendirme

class PasswordResetConfirmScreen extends StatefulWidget {
  final String email; // Bir önceki ekrandan gelen e-posta

  const PasswordResetConfirmScreen({Key? key, required this.email}) : super(key: key);

  @override
  _PasswordResetConfirmScreenState createState() =>
      _PasswordResetConfirmScreenState();
}

class _PasswordResetConfirmScreenState
    extends State<PasswordResetConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPassword1Controller = TextEditingController();
  final TextEditingController _newPassword2Controller = TextEditingController();
  bool _isLoading = false;
  String _message = '';
  Color _messageColor = Colors.redAccent;

  @override
  void dispose() {
    _codeController.dispose();
    _newPassword1Controller.dispose();
    _newPassword2Controller.dispose();
    super.dispose();
  }

  Future<void> _confirmPasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      await ApiService.confirmPasswordResetWithCode(
        widget.email, // Kullanıcının girdiği email
        _codeController.text.trim(),
        _newPassword1Controller.text,
        _newPassword2Controller.text,
      );
      if (mounted) {
        setState(() {
          _message = l10n.passwordResetConfirmSuccessMessage;
          _messageColor = Colors.green;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message), backgroundColor: _messageColor, duration: const Duration(seconds: 3)),
        );
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false, // Tüm önceki rotaları kaldır
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
        title: Text(l10n.passwordResetConfirmTitle, style: const TextStyle(color: Colors.white)),
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
                          l10n.passwordResetConfirmInstruction,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _codeController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: l10n.passwordResetConfirmCodeLabel,
                            labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: Icon(Icons.vpn_key_outlined, color: Colors.grey.shade600),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.passwordResetConfirmCodeValidator;
                            }
                            if (value.trim().length != 6) {
                              return l10n.passwordResetConfirmCodeLengthValidator;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPassword1Controller,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: l10n.accountSettingsNewPasswordLabel,
                            labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.passwordHintRequired;
                            }
                            if (value.length < 6) {
                              return l10n.passwordHintMinLength;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPassword2Controller,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: l10n.accountSettingsConfirmNewPasswordLabel,
                             labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.7),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                             prefixIcon: Icon(Icons.lock_reset_outlined, color: Colors.grey.shade600),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.accountSettingsValidatorConfirmNewPassword;
                            }
                            if (value != _newPassword1Controller.text) {
                              return l10n.accountSettingsErrorPasswordsMismatch;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _confirmPasswordReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(50),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                              : Text(l10n.passwordResetConfirmResetButton, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
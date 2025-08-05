// lib/screens/admin_user_approval_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import '../widgets/admin/pending_approval_card.dart'; // Yeni widget

class UserApprovalScreen extends StatefulWidget {
  final String token;
  const UserApprovalScreen({Key? key, required this.token}) : super(key: key);

  @override
  _UserApprovalScreenState createState() => _UserApprovalScreenState();
}

class _UserApprovalScreenState extends State<UserApprovalScreen> {
  bool _isLoading = true;
  List<dynamic> _pendingUsers = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPendingUsers();
  }

  Future<void> _fetchPendingUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final users = await AdminService.fetchPendingApprovalUsers(widget.token);
      if (mounted) {
        setState(() {
          _pendingUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveUser(int userId, String username) async {
    // Onaylama için ek bir dialog göstermeden doğrudan onaylayabiliriz,
    // ya da isteğe bağlı bir onay dialogu eklenebilir.
    // Şimdilik doğrudan onaylayalım.
    try {
      await AdminService.approveUser(widget.token, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'$username' kullanıcısı onaylandı ve aktifleştirildi."), backgroundColor: Colors.green),
        );
        _fetchPendingUsers(); // Listeyi yenile
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kullanıcı onaylanırken hata: ${e.toString().replaceFirst("Exception: ", "")}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Üyelik Talepleri'),
        centerTitle: true,
         flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade900, Colors.green.shade700.withOpacity(0.8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.orangeAccent, fontSize: 16), textAlign: TextAlign.center),
                  ))
                : RefreshIndicator(
                    onRefresh: _fetchPendingUsers,
                    color: Colors.white,
                    backgroundColor: Colors.teal.shade700,
                    child: _pendingUsers.isEmpty
                        ? const Center(child: Text("Onay bekleyen kullanıcı bulunmamaktadır.", style: TextStyle(color: Colors.white70, fontSize: 16)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _pendingUsers.length,
                            itemBuilder: (context, index) {
                              final user = _pendingUsers[index];
                              return PendingApprovalCard(
                                user: user,
                                onApprove: () => _approveUser(user['id'], user['username']),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}
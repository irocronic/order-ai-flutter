// lib/screens/admin_home.dart
import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../widgets/admin/business_owner_admin_card.dart';
import '../widgets/admin/admin_confirmation_dialog.dart';
import 'admin_user_approval_screen.dart'; // Onay ekranı

class AdminHome extends StatefulWidget {
  final String token;
  const AdminHome({Key? key, required this.token}) : super(key: key);

  @override
  _AdminHomeState createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0; // BottomNavigationBar için aktif sekme indeksi
  bool _isLoadingBusinessOwners = true;
  List<dynamic> _businessOwners = [];
  String _errorMessageBusinessOwners = '';

  // Sayfaları tutacak liste
  late List<Widget> _adminPages;

  // AppBar başlıkları
  final List<String> _appBarTitles = [
    "Admin - Kullanıcı Yönetimi",
    "Admin - Üyelik Talepleri",
  ];

  @override
  void initState() {
    super.initState();
    _adminPages = [
      _buildBusinessOwnersPage(), // İlk sekme için içerik
      UserApprovalScreen(token: widget.token), // İkinci sekme için içerik
    ];
    _fetchBusinessOwners();
  }

  Future<void> _fetchBusinessOwners() async {
    if (!mounted) return;
    // Sadece ilk sekme aktifken veya veri boşken yükleme yap
    if (_currentIndex == 0 || _businessOwners.isEmpty) {
      setState(() {
        _isLoadingBusinessOwners = true;
        _errorMessageBusinessOwners = '';
      });
      try {
        final owners = await AdminService.fetchBusinessOwners(widget.token);
        if (mounted) {
          setState(() {
            _businessOwners = owners;
            _isLoadingBusinessOwners = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessageBusinessOwners = e.toString().replaceFirst("Exception: ", "");
            _isLoadingBusinessOwners = false;
          });
        }
      }
    }
  }

  Future<void> _toggleUserActiveStatus(int userId, bool currentStatus, {bool isStaff = false}) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmationDialog(
        title: currentStatus ? "Hesabı Pasifleştir" : "Hesabı Aktifleştir",
        content: "Bu kullanıcı hesabının durumunu değiştirmek istediğinizden emin misiniz?",
        confirmButtonText: currentStatus ? "Pasifleştir" : "Aktifleştir",
      ),
    );

    if (confirm == true && mounted) {
      try {
        await AdminService.setUserActiveStatus(widget.token, userId, !currentStatus);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kullanıcı durumu güncellendi."), backgroundColor: Colors.green),
          );
          // Aktif sekme kullanıcı listesi ise listeyi yenile
          if (_currentIndex == 0) {
            _fetchBusinessOwners();
          }
          // Eğer onay ekranındaysak ve bir kullanıcıyı buradan (yanlışlıkla) (de)aktive ettiysek,
          // o ekran kendi listesini yenilemeli. Bu metot şu an sadece _AdminHomeState'ten çağrılıyor.
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Durum güncellenirken hata: ${e.toString().replaceFirst("Exception: ", "")}"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(int userId, String username, String userType) async {
    String warningMessage = userType == 'business_owner'
        ? "UYARI: Bu işletme sahibini silmek, işletmeye ait tüm verileri (masalar, menüler, siparişler, personel vb.) de SİLECEKTİR. Devam etmek istediğinize emin misiniz?"
        : "'$username' adlı personeli silmek istediğinize emin misiniz?";

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AdminConfirmationDialog(
        title: "Kullanıcıyı Sil",
        content: warningMessage,
        confirmButtonText: "Evet, Sil",
        isDestructive: true,
      ),
    );

    if (confirm == true && mounted) {
      try {
        await AdminService.deleteUserAccount(widget.token, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("'$username' kullanıcısı silindi."), backgroundColor: Colors.orangeAccent),
          );
          if (_currentIndex == 0) { // Sadece işletme sahipleri listesi aktifse yenile
            _fetchBusinessOwners();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Kullanıcı silinirken hata: ${e.toString().replaceFirst("Exception: ", "")}"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildBusinessOwnersPage() {
    return _isLoadingBusinessOwners
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _errorMessageBusinessOwners.isNotEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessageBusinessOwners, style: const TextStyle(color: Colors.orangeAccent, fontSize: 16), textAlign: TextAlign.center),
              ))
            : RefreshIndicator(
                onRefresh: _fetchBusinessOwners,
                color: Colors.white,
                backgroundColor: Colors.blue.shade700,
                child: _businessOwners.isEmpty
                    ? Center(child: Text("Sistemde kayıtlı işletme sahibi bulunamadı.", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _businessOwners.length,
                        itemBuilder: (context, index) {
                          final owner = _businessOwners[index];
                          return BusinessOwnerAdminCard(
                            owner: owner,
                            token: widget.token,
                            onToggleActive: () => _toggleUserActiveStatus(owner['id'], owner['is_active']),
                            onDelete: () => _deleteUser(owner['id'], owner['username'], 'business_owner'),
                            onStaffToggleActive: (staffId, currentStatus) => _toggleUserActiveStatus(staffId, currentStatus, isStaff: true),
                            onStaffDelete: (staffId, staffUsername) => _deleteUser(staffId, staffUsername, 'staff'),
                          );
                        },
                      ),
              );
  }


  @override
  Widget build(BuildContext context) {
    // _adminPages initState içinde doldurulduğu için burada tekrar oluşturmaya gerek yok.
    // Sadece _currentIndex değiştiğinde içeriğin yenilenmesi için _buildBusinessOwnersPage'i güncelledik.
    // Eğer UserApprovalScreen'in de bir refresh mekanizması varsa o da kendi içinde halledecektir.
    if (_currentIndex == 0 && _adminPages[0] is! RefreshIndicator) { // İlk sayfa içeriğini güncelle (eğer değiştiyse)
        _adminPages[0] = _buildBusinessOwnersPage();
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_currentIndex], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900], // Mavi tonları
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900.withOpacity(0.95), Colors.blue.shade500.withOpacity(0.85)], // Mavi tonları
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack( // Sayfalar arası geçiş için IndexedStack
          index: _currentIndex,
          children: _adminPages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Eğer "Kullanıcılar" sekmesine geri dönülüyorsa ve o an yüklenmiyorsa, listeyi yenileyebiliriz.
          if (index == 0 && !_isLoadingBusinessOwners) {
            _fetchBusinessOwners();
          }
          // UserApprovalScreen zaten kendi initState'inde veya görünür olduğunda veri çeker.
        },
        backgroundColor: Colors.blue.shade800, // Navbar arka planı
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        type: BottomNavigationBarType.fixed, // İkiden fazla item için
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center_outlined),
            activeIcon: Icon(Icons.business_center),
            label: 'İşletmeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_reg_outlined),
            activeIcon: Icon(Icons.how_to_reg),
            label: 'Üyelik Talepleri', // İsim "Üyelik Talepleri" olarak güncellendi
          ),
        ],
      ),
    );
  }
}
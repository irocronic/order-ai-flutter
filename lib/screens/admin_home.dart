// lib/screens/admin_home.dart
import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../widgets/admin/business_owner_admin_card.dart';
import '../widgets/admin/admin_confirmation_dialog.dart';
import 'admin_user_approval_screen.dart'; // Onay ekranı
import 'admin_notification_settings_screen.dart';

class AdminHome extends StatefulWidget {
  final String token;
  const AdminHome({Key? key, required this.token}) : super(key: key);

  @override
  _AdminHomeState createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;
  bool _isLoadingBusinessOwners = true;
  List<dynamic> _businessOwners = [];
  String _errorMessageBusinessOwners = '';

  // AppBar başlıkları
  final List<String> _appBarTitles = [
    "Admin - Kullanıcı Yönetimi",
    "Admin - Üyelik Talepleri",
  ];

  @override
  void initState() {
    super.initState();
    _fetchBusinessOwners();
  }

  Future<void> _fetchBusinessOwners() async {
    if (!mounted) return;
    
    // Yalnızca ilk sekme aktifken veya veri boşken tam yükleme yap
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

  // ==================== GÜNCELLENMİŞ FONKSİYON ====================
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
        // API'den dönen güncellenmiş kullanıcı verisini bir değişkene ata
        final updatedUserData = await AdminService.setUserActiveStatus(widget.token, userId, !currentStatus);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kullanıcı durumu güncellendi."), backgroundColor: Colors.green),
          );

          // Eğer güncellenen kişi bir işletme sahibi ise listeyi anında güncelle
          if (!isStaff) {
            setState(() {
              final index = _businessOwners.indexWhere((owner) => owner['id'] == userId);
              if (index != -1) {
                _businessOwners[index] = updatedUserData;
              }
            });
          } else {
            // Eğer güncellenen bir personel ise, o personelin ait olduğu
            // işletme kartının güncel veriyi (örn. aktif personel sayısı)
            // göstermesi için tüm listeyi yeniden çekmek en basit ve garantili yoldur.
            _fetchBusinessOwners();
          }
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
  // ==================== GÜNCELLEME SONU ====================

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
          if (_currentIndex == 0) {
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
                            key: ValueKey(owner['id']), // Performans ve doğru rebuild için Key eklemek iyidir.
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
    // ==================== GÜNCELLENMİŞ BÖLÜM ====================
    // Sayfa listesi artık build metodu içinde dinamik olarak oluşturuluyor.
    // Bu, setState çağrıldığında arayüzün doğru şekilde yeniden çizilmesini garantiler.
    final List<Widget> adminPages = [
      _buildBusinessOwnersPage(),
      UserApprovalScreen(token: widget.token),
    ];
    // ==================== GÜNCELLEME SONU ====================

    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_currentIndex], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
           icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: "Bildirim Ayarları",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminNotificationSettingsScreen(token: widget.token),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900.withOpacity(0.95), Colors.blue.shade500.withOpacity(0.85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        // IndexedStack artık doğrudan build'de oluşturulan listeyi kullanıyor.
        child: IndexedStack(
          index: _currentIndex,
          children: adminPages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Not: UserApprovalScreen kendi veri çekme mantığına sahip olduğu için
          // burada sadece _currentIndex == 0 durumunu kontrol etmek yeterlidir.
          if (index == 0) {
            _fetchBusinessOwners();
          }
        },
        backgroundColor: Colors.blue.shade800,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center_outlined),
            activeIcon: Icon(Icons.business_center),
            label: 'İşletmeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_reg_outlined),
            activeIcon: Icon(Icons.how_to_reg),
            label: 'Üyelik Talepleri',
          ),
        ],
      ),
    );
  }
}
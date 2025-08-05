// lib/screens/pager_assignment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/pager_service.dart';
import '../models/pager_device_model.dart';
import '../services/user_session.dart';
import 'package:flutter/foundation.dart';

class PagerAssignmentScreen extends StatefulWidget {
  const PagerAssignmentScreen({Key? key}) : super(key: key);

  @override
  State<PagerAssignmentScreen> createState() => _PagerAssignmentScreenState();
}

class _PagerAssignmentScreenState extends State<PagerAssignmentScreen> {
  // === HATA DÜZELTME 1: Servis örneği oluşturuluyor ===
  final PagerService _pagerService = PagerService.instance;

  List<PagerSystemDevice> _availablePagers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _didFetchData = false;

  @override
  void initState() {
    super.initState();
    // fetch işlemi didChangeDependencies'e taşındı
  }

  // === HATA DÜZELTME 2: didChangeDependencies içinde servis başlatılıyor ===
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      final l10n = AppLocalizations.of(context)!;
      _pagerService.init(l10n); // Servisi l10n ile başlat
      _fetchAvailablePagers();
      _didFetchData = true;
    }
  }

  Future<void> _fetchAvailablePagers() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // === HATA DÜZELTME 3: Statik çağrı instance çağrısına dönüştürüldü ===
      final allPagers = await _pagerService.fetchPagers(UserSession.token);
      if (mounted) {
        setState(() {
          _availablePagers = allPagers.where((p) => p.status == 'available').toList();
          if (_availablePagers.isEmpty && allPagers.isNotEmpty) {
            _errorMessage = l10n.pagerAssignmentErrorNoAvailable;
          } else if (_availablePagers.isEmpty && allPagers.isEmpty) {
            _errorMessage = l10n.pagerAssignmentErrorNoRegistered;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst("Exception: ", ""));
      }
      debugPrint("Hata - Boşta Pager Çekme: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectPagerAndReturn(PagerSystemDevice pager) {
    Navigator.pop(context, pager.deviceId); // Sadece Bluetooth device_id'yi döndür
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pagerAssignmentScreenTitle, style: const TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.pagerAssignmentTooltipRefresh,
            onPressed: _isLoading ? null : _fetchAvailablePagers,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueGrey.shade800.withOpacity(0.9),
              Colors.blueGrey.shade900.withOpacity(0.95),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _errorMessage.isNotEmpty && _availablePagers.isEmpty
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.orangeAccent, fontSize: 16), textAlign: TextAlign.center),
                  ))
                : _availablePagers.isEmpty
                    ? Center(
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phonelink_off_outlined, size: 60, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage.isNotEmpty ? _errorMessage : l10n.pagerAssignmentDefaultError,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _errorMessage.isNotEmpty ? Colors.orangeAccent : Colors.white.withOpacity(0.7), fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.createOrderButtonRetry),
                            onPressed: _fetchAvailablePagers,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade50,
                              foregroundColor: Colors.blueGrey.shade900,
                            ),
                          )
                        ],
                      ))
                    : RefreshIndicator(
                        onRefresh: _fetchAvailablePagers,
                        color: Colors.white,
                        backgroundColor: Colors.blueGrey.shade700,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                          itemCount: _availablePagers.length,
                          itemBuilder: (context, index) {
                            final pager = _availablePagers[index];
                            return Card(
                              color: Colors.blueGrey.shade700.withOpacity(0.85),
                              margin: const EdgeInsets.symmetric(vertical: 5.0),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)
                              ),
                              child: ListTile(
                                leading: Icon(Icons.speaker_phone_outlined, color: Colors.tealAccent.shade100.withOpacity(0.9)),
                                title: Text(pager.name ?? pager.deviceId, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.95))),
                                subtitle: Text("ID: ${pager.deviceId}\n${l10n.pagerAssignmentStatusLabel(pager.statusDisplay)}", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                                isThreeLine: true,
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.tealAccent.shade400,
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                                  ),
                                  onPressed: () => _selectPagerAndReturn(pager),
                                  child: Text(l10n.buttonAssign, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                onTap: () => _selectPagerAndReturn(pager),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
// lib/widgets/admin/business_owner_admin_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'staff_admin_card.dart';
import '../../services/admin_service.dart';

class BusinessOwnerAdminCard extends StatefulWidget {
  final dynamic owner;
  final String token;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final Function(int staffId, bool currentStatus) onStaffToggleActive;
  final Function(int staffId, String staffUsername) onStaffDelete;

  const BusinessOwnerAdminCard({
    Key? key,
    required this.owner,
    required this.token,
    required this.onToggleActive,
    required this.onDelete,
    required this.onStaffToggleActive,
    required this.onStaffDelete,
  }) : super(key: key);

  @override
  _BusinessOwnerAdminCardState createState() => _BusinessOwnerAdminCardState();
}

class _BusinessOwnerAdminCardState extends State<BusinessOwnerAdminCard> {
  bool _isExpanded = false;
  bool _isLoadingStaff = false;
  List<dynamic> _staffList = [];
  String _staffErrorMessage = '';

  Future<void> _fetchStaff() async {
    if (!_isExpanded || _staffList.isNotEmpty) return;
    setState(() {
      _isLoadingStaff = true;
      _staffErrorMessage = '';
    });
    try {
      final staff = await AdminService.fetchStaffForOwner(widget.token, widget.owner['id']);
      if (mounted) {
        setState(() {
          _staffList = staff;
          _isLoadingStaff = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _staffErrorMessage = "Personel listesi alınamadı: ${e.toString().replaceFirst("Exception: ", "")}";
          _isLoadingStaff = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isActive = widget.owner['is_active'] ?? false;
    
    // ==================== YENİ VERİLERİ ÇEKME ====================
    final String planName = widget.owner['subscription_plan_name'] ?? 'Plan Yok';
    final String subStatus = widget.owner['subscription_status'] ?? 'Bilinmiyor';
    final int? trialDays = widget.owner['trial_days_remaining'];
    // ==========================================================

    return Card(
      color: Colors.white.withOpacity(0.85),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
          width: 1.5,
        ),
      ),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
          if (expanded) {
            _fetchStaff();
          }
        },
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            Icons.business_center,
            color: isActive ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        title: Text(
          widget.owner['username'] ?? 'Bilinmeyen Kullanıcı',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.owner['owned_business_details']?['name'] ?? 'İşletme Adı Yok'),
            const SizedBox(height: 4),
            Row(
              children: [
                Text("Durum: ", style: TextStyle(color: Colors.grey.shade700)),
                Text(
                  isActive ? "Aktif" : "Pasif",
                  style: TextStyle(
                    color: isActive ? Colors.green.shade800 : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // ==================== YENİ WIDGET'LAR BURADA ====================
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.workspace_premium_outlined, size: 16, color: Colors.blueGrey.shade700),
                const SizedBox(width: 4),
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                    children: <TextSpan>[
                      TextSpan(text: 'Abonelik: ', style: TextStyle(color: Colors.grey.shade800)),
                      TextSpan(text: '$planName ($subStatus)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
            if (trialDays != null && trialDays >= 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_bottom_rounded, size: 16, color: Colors.orange.shade800),
                    const SizedBox(width: 4),
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                        children: <TextSpan>[
                          TextSpan(text: 'Deneme Süresi: ', style: TextStyle(color: Colors.grey.shade800)),
                          TextSpan(text: '$trialDays gün kaldı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // =============================================================
          ],
        ),
        trailing: const SizedBox.shrink(), // Varsayılan oku gizle
        children: [
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.group_outlined, color: Colors.blue.shade800),
                  label: Text("${widget.owner['staff_count'] ?? 0} Personel"),
                  onPressed: () {
                    // Bu butona basıldığında zaten genişlediği için tekrar fetch tetiklemeye gerek yok.
                  },
                ),
                TextButton.icon(
                  icon: Icon(isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined, color: isActive ? Colors.red.shade700 : Colors.green.shade700),
                  label: Text(isActive ? "Pasifleştir" : "Aktifleştir"),
                  onPressed: widget.onToggleActive,
                ),
                TextButton.icon(
                  icon: Icon(Icons.delete_forever_outlined, color: Colors.red.shade800),
                  label: const Text("Sil"),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
          if (_isExpanded)
            _isLoadingStaff
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                : _staffErrorMessage.isNotEmpty
                    ? Center(child: Text(_staffErrorMessage, style: const TextStyle(color: Colors.red)))
                    : _staffList.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text("Bu işletmeye ait personel bulunmuyor.")))
                        : Column(
                            children: _staffList.map((staff) {
                              return StaffAdminCard(
                                staff: staff,
                                onToggleActive: () => widget.onStaffToggleActive(staff['id'], staff['is_active']),
                                onDelete: () => widget.onStaffDelete(staff['id'], staff['username']),
                              );
                            }).toList(),
                          ),
        ],
      ),
    );
  }
}
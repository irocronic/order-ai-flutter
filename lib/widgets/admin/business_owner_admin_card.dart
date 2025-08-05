// lib/widgets/admin/business_owner_admin_card.dart
import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'staff_admin_card.dart';

class BusinessOwnerAdminCard extends StatefulWidget {
  final dynamic owner;
  final String token;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final Future<void> Function(int userId, bool currentStatus) onStaffToggleActive;
  final Future<void> Function(int staffId, String staffUsername) onStaffDelete;

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
    if (!_isExpanded || !mounted) return;
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
          _staffErrorMessage = e.toString().replaceFirst("Exception: ", "");
          _isLoadingStaff = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.owner['is_active'] ?? false;
    final businessDetails = widget.owner['owned_business_details'];
    final String businessName = businessDetails != null ? businessDetails['name'] : "İşletme Bilgisi Yok";
    final int staffCount = widget.owner['staff_count'] ?? 0;

    return Card(
      color: Colors.white.withOpacity(0.85),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: isActive ? Colors.green.shade300 : Colors.red.shade300, width: 1.5),
      ),
      child: ExpansionTile(
        key: PageStorageKey('owner_${widget.owner['id']}'),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
          if (expanded && _staffList.isEmpty && staffCount > 0) {
            _fetchStaff();
          }
        },
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
          child: Icon(isActive ? Icons.storefront : Icons.do_not_disturb_on_outlined, color: Colors.white),
        ),
        title: Text(
          "${widget.owner['username']} (${widget.owner['first_name'] ?? ''} ${widget.owner['last_name'] ?? ''})",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade800),
        ),
        subtitle: Text(
          "İşletme: $businessName\nPersonel Sayısı: $staffCount\nDurum: ${isActive ? 'Aktif' : 'Pasif'}",
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isActive ? Icons.toggle_on : Icons.toggle_off, color: isActive ? Colors.green : Colors.grey, size: 28),
              tooltip: isActive ? "Pasifleştir" : "Aktifleştir",
              onPressed: widget.onToggleActive,
            ),
            IconButton(
              icon: Icon(Icons.delete_forever, color: Colors.red.shade700, size: 28),
              tooltip: "İşletme Sahibini Sil",
              onPressed: widget.onDelete,
            ),
          ],
        ),
        children: <Widget>[
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(top:0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Text("Personel Listesi:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade800)),
                  if (_isLoadingStaff)
                    const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (_staffErrorMessage.isNotEmpty)
                    Padding(padding: const EdgeInsets.all(8.0), child: Text(_staffErrorMessage, style: const TextStyle(color: Colors.redAccent)))
                  else if (_staffList.isEmpty)
                    const Padding(padding: EdgeInsets.all(8.0), child: Text("Bu işletmeye ait personel bulunmamaktadır.", style: TextStyle(fontStyle: FontStyle.italic)))
                  else
                    ..._staffList.map((staff) => StaffAdminCard(
                        staff: staff,
                        onToggleActive: () => widget.onStaffToggleActive(staff['id'], staff['is_active']),
                        onDelete: () => widget.onStaffDelete(staff['id'], staff['username']),
                      )).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
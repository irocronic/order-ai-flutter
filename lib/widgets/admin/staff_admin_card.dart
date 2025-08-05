// lib/widgets/admin/staff_admin_card.dart
import 'package:flutter/material.dart';

class StaffAdminCard extends StatelessWidget {
  final dynamic staff;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const StaffAdminCard({
    Key? key,
    required this.staff,
    required this.onToggleActive,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isActive = staff['is_active'] ?? false;
    final List<String> permissions = staff['staff_permissions'] != null
        ? List<String>.from(staff['staff_permissions'])
        : [];

    return Card(
      color: Colors.white.withOpacity(0.9),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: isActive ? Colors.lightGreen.shade400 : Colors.red.shade200, width: 1),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.person, color: isActive ? Colors.green.shade700 : Colors.grey.shade600),
        title: Text(
          "${staff['username']} (${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''})",
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey.shade800),
        ),
        subtitle: Text(
          "Email: ${staff['email'] ?? '-'}\nİzinler: ${permissions.isNotEmpty ? permissions.join(', ') : 'Yok'}\nDurum: ${isActive ? 'Aktif' : 'Pasif'}",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(isActive ? Icons.toggle_on : Icons.toggle_off, color: isActive ? Colors.green : Colors.grey),
              tooltip: isActive ? "Pasifleştir" : "Aktifleştir",
              iconSize: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onToggleActive,
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade400),
              tooltip: "Personeli Sil",
              iconSize: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
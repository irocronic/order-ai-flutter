// lib/models/home_menu_item.dart

import 'package:flutter/material.dart';
import '../models/staff_permission_keys.dart';

/// Ana ekrandaki her bir menü kartını temsil eden veri modeli.
class HomeMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback Function(BuildContext context) onTapBuilder;
  final Color baseColor;
  final String permissionKey;
  final bool requiresBusinessOwner;

  const HomeMenuItem({
    required this.icon,
    required this.title,
    required this.onTapBuilder,
    required this.baseColor,
    this.permissionKey = '', // Varsayılan olarak boş, yani herkese açık
    this.requiresBusinessOwner = false,
  });
}
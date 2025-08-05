// lib/models/home_menu_section.dart

import 'home_menu_item.dart';

/// Ana ekrandaki menü kartlarını gruplamak için kullanılan bölüm modeli.
class HomeMenuSection {
  final String title;
  final List<HomeMenuItem> items;

  const HomeMenuSection({
    required this.title,
    required this.items,
  });
}
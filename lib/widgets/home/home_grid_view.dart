// lib/widgets/home/home_grid_view.dart DOSYASINA EKLEYİN

import 'package:flutter/material.dart';
import '../../models/home_menu_item.dart';
import 'home_menu_card.dart';

class HomeGridView extends StatelessWidget {
  final List<HomeMenuItem> menuItems;

  const HomeGridView({Key? key, required this.menuItems}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ekran boyutuna göre dinamik grid yapısı
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 1200 ? 5 : (screenWidth > 800 ? 4 : (screenWidth > 550 ? 3 : 2));
    double childAspectRatio = screenWidth > 550 ? 1.1 : 1.0;

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        return HomeMenuCard(item: menuItems[index]);
      },
    );
  }
}
// lib/widgets/home/business_owner_bottom_nav.dart

import 'package:flutter/material.dart';

class BusinessOwnerBottomNav extends StatelessWidget {
  final List<BottomNavigationBarItem> activeNavBarItems;
  final int currentIndex;
  final Function(int) onTap;

  const BusinessOwnerBottomNav({
    Key? key,
    required this.activeNavBarItems,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (activeNavBarItems.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade700,
            Colors.blue.shade800,
            Colors.teal.shade700,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, -1),
          )
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.65),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: activeNavBarItems,
      ),
    );
  }
}
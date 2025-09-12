// lib/widgets/setup_wizard/menu_items/utils/icon_utils.dart
import 'package:flutter/material.dart';

class IconUtils {
  static IconData getIconFromName(String iconName) {
    switch (iconName) {
      case 'restaurant_outlined': return Icons.restaurant_outlined;
      case 'restaurant': return Icons.restaurant;
      case 'dinner_dining': return Icons.dinner_dining;
      case 'local_cafe': return Icons.local_cafe;
      case 'coffee': return Icons.coffee;
      case 'cake': return Icons.cake;
      case 'fastfood': return Icons.fastfood;
      case 'lunch_dining': return Icons.lunch_dining;
      case 'local_bar': return Icons.local_bar;
      case 'wine_bar': return Icons.wine_bar;
      case 'whatshot': return Icons.whatshot;
      case 'ac_unit': return Icons.ac_unit;
      case 'favorite': return Icons.favorite;
      case 'mood': return Icons.mood;
      case 'add_circle': return Icons.add_circle;
      case 'local_drink': return Icons.local_drink;
      case 'sports_bar': return Icons.sports_bar;
      default: return Icons.label_outline;
    }
  }
}
import 'package:flutter/material.dart';

class PlaceholderService {
  static IconData getIcon(String category) {
    final cat = category.toUpperCase();
    if (cat.contains('SNACK')) return Icons.cookie_rounded;
    if (cat.contains('BEVERAGE')) return Icons.local_cafe_rounded;
    if (cat.contains('DRINK')) return Icons.local_drink_rounded;
    if (cat.contains('STATIONERY')) return Icons.edit_note_rounded;
    if (cat.contains('HYGIENE')) return Icons.clean_hands_rounded;
    if (cat.contains('DAIRY')) return Icons.egg_rounded;
    if (cat.contains('PERSONAL')) return Icons.spa_rounded;
    if (cat.contains('MEDICINE') || cat.contains('WELLNESS') || cat.contains('FIRST AID')) return Icons.medication_rounded;
    if (cat.contains('GROCERY') || cat.contains('KIRYANA') || cat.contains('STAPLES') || cat.contains('PULSES')) return Icons.shopping_basket_rounded;
    if (cat.contains('EXOTIC') || cat.contains('FRUIT')) return Icons.apple_rounded;
    if (cat.contains('VEGETABLE') || cat.contains('GREENS') || cat.contains('ORGANIC') || cat.contains('HERBS')) return Icons.eco_rounded;
    if (cat.contains('TECH') || cat.contains('ELECTRONIC') || cat.contains('CABLE')) return Icons.devices_other_rounded;
    if (cat.contains('KITCHEN') || cat.contains('DORM')) return Icons.kitchen_rounded;
    if (cat.contains('BAKERY')) return Icons.bakery_dining_rounded;
    if (cat.contains('BURGER')) return Icons.lunch_dining_rounded;
    if (cat.contains('MOMO')) return Icons.cookie_rounded;
    if (cat.contains('ROLL')) return Icons.wrap_text_rounded;
    if (cat.contains('PIZZA')) return Icons.local_pizza_rounded;
    if (cat.contains('PASTA') || cat.contains('NOODLE')) return Icons.ramen_dining_rounded;
    
    // Generic Hashing for New Categories
    final List<IconData> genericIcons = [
      Icons.inventory_2_rounded,
      Icons.takeout_dining_rounded,
      Icons.category_rounded,
      Icons.apps_rounded,
      Icons.layers_rounded,
      Icons.dashboard_rounded,
      Icons.storefront_rounded,
      Icons.shopping_bag_rounded,
      Icons.widgets_rounded,
      Icons.auto_awesome_mosaic_rounded,
    ];
    final int index = category.hashCode.abs() % genericIcons.length;
    return genericIcons[index];
  }

  static Color getColor(String category) {
    final cat = category.toUpperCase();
    
    final List<Color> genericColors = [
      Colors.indigoAccent,
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.deepOrangeAccent,
      Colors.blueGrey,
      Colors.lightGreenAccent,
      Colors.pinkAccent,
      Colors.amberAccent,
      Colors.tealAccent,
      Colors.deepPurpleAccent,
      Colors.blueAccent,
      Colors.orangeAccent,
    ];
    final int index = category.hashCode.abs() % genericColors.length;
    return genericColors[index];
  }

  static Color getProductColor(String productId) {
    // Generate a deterministic hue (0-360) for true rainbow randomness per product
    final double hue = (productId.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.6).toColor();
  }

  static Widget buildPlaceholder(String category, String productId, {double size = 40, bool isDark = true}) {
    final icon = getIcon(category);
    final color = getProductColor(productId);
    return Container(
      width: double.infinity, height: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.05 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: Icon(icon, color: color.withOpacity(0.4), size: size)),
    );
  }
}

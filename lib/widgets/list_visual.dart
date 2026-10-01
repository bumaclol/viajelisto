import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ListVisual {
  const ListVisual({
    required this.icon,
    required this.color,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final Color border;
}

ListVisual visualFor(String iconKey) {
  switch (iconKey) {
    case 'beach':
      return const ListVisual(
        icon: Icons.beach_access_rounded,
        color: Color(0xFFE38B2C),
        background: Color(0xFFFFF6E8),
        border: Color(0xFFF3D7B0),
      );
    case 'camping':
      return const ListVisual(
        icon: Icons.park_rounded,
        color: Color(0xFF2E9B57),
        background: Color(0xFFE8F8EE),
        border: Color(0xFFC9EBD6),
      );
    case 'forest':
      return const ListVisual(
        icon: Icons.forest_rounded,
        color: Color(0xFF6B63C6),
        background: Color(0xFFF3F0FC),
        border: Color(0xFFDDD7F3),
      );
    default:
      return const ListVisual(
        icon: Icons.luggage_rounded,
        color: blue,
        background: Color(0xFFEEF4FF),
        border: Color(0xFFD5E3FF),
      );
  }
}

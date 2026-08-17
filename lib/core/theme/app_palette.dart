import 'package:flutter/material.dart';

/// Brand colours. Everything visual should read from here or from the
/// generated [ColorScheme] — never from ad-hoc hex values in widgets.
class AppPalette {
  const AppPalette._();

  static const Color primary = Color(0xFF4F6BFF);
  static const Color secondary = Color(0xFF8A5CF6);
  static const Color success = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF16A34A);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color streak = Color(0xFFFF7A29);
  static const Color xp = Color(0xFFFFC531);

  static const Color bronze = Color(0xFFCD7F32);
  static const Color silver = Color(0xFF9CA3AF);
  static const Color gold = Color(0xFFF5B400);
  static const Color platinum = Color(0xFF38BDF8);
  static const Color diamond = Color(0xFF22D3EE);

  static const List<Color> avatarColors = <Color>[
    Color(0xFF4F6BFF),
    Color(0xFF8A5CF6),
    Color(0xFF22C55E),
    Color(0xFFFF7A29),
    Color(0xFFEF4444),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  static Color avatarColor(int avatarId) =>
      avatarColors[avatarId.abs() % avatarColors.length];
}

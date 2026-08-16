import 'package:flutter/material.dart';

class AppColors {
  static const Color accentBlue = Color(0xFF573AFE);
  static const Color accentBlueLight = Color(0xFFEFF6FF);

  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgHighlight = Color(0xFFEFF6FF);
  static const Color bgInput = Color(0xFFF4F4F5);

  static const Color bgMessageIn = Color(0xFFF4F4F5);
  static const Color bgMessageOut = Color(0xFF573AFE);

  static const Color borderDefault = Color(0xFFE4E4E7);
  static const Color successGreen = Color(0xFF22C55E);

  static const Color textPrimary = Color(0xFF18181B);
  static const Color textSecondary = Color(0xFF71717A);
  static const Color textTertiary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFFD4D4D8);
  static const Color textOnAccent = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFEF4444);

  static const List<Color> contactAvatarColors = <Color>[
    accentBlue,
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF0EA5E9),
  ];

  static Color contactAvatarColor(int index) =>
      contactAvatarColors[index % contactAvatarColors.length];
}

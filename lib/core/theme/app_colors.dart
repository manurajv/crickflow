import 'package:flutter/material.dart';

/// Dark sports broadcast theme — blue, gold, red accents.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF141B2D);
  static const Color surfaceElevated = Color(0xFF1E2940);
  static const Color card = Color(0xFF1A2332);

  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryBlueLight = Color(0xFF42A5F5);
  static const Color gold = Color(0xFFFFC107);
  static const Color goldDark = Color(0xFFFFA000);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentGreen = Color(0xFF43A047);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF78909C);

  static const Color scoreboardBg = Color(0xFF0D47A1);
  static const Color liveIndicator = Color(0xFFE53935);
  static const Color border = Color(0xFF2A3F5F);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0A0E17)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFC107), Color(0xFFFFA000)],
  );
}

import 'package:flutter/material.dart';

import 'cf_colors.dart';

/// Legacy color tokens — prefer [CfColors] via `context.cf` in widgets.
///
/// Brand tokens are shared across themes. Surface/text tokens mirror the dark
/// palette for backwards compatibility during migration.
class AppColors {
  AppColors._();

  static const Color primaryBlue = CfColors.primaryBlue;
  static const Color primaryBlueLight = CfColors.primaryBlueLight;
  static const Color gold = CfColors.gold;
  static const Color goldDark = CfColors.goldDark;
  static const Color accentRed = CfColors.accentRed;
  static const Color accentGreen = CfColors.accentGreen;
  static const Color liveIndicator = CfColors.liveIndicator;

  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF141B2D);
  static const Color surfaceElevated = Color(0xFF1E2940);
  static const Color card = Color(0xFF1A2332);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF78909C);
  static const Color scoreboardBg = Color(0xFF0D47A1);
  static const Color border = Color(0xFF2A3F5F);
  static const Color chromeBackground = Color(0xFF141B2D);
  static const Color chromeForeground = Color(0xFFFFFFFF);
  static const Color navSelected = CfColors.gold;
  static const Color navUnselected = Color(0xFFB0BEC5);
  static const Color navIndicator = Color(0x402196F3);

  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A2744), Color(0xFF141B2D)],
  );
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0A0E17)],
  );
  static const LinearGradient goldGradient = CfColors.goldGradient;
}

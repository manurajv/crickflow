import 'package:flutter/material.dart';

import '../../../../../../core/theme/cf_colors.dart';
import '../../../../data/models/stream_overlay_theme.dart';

/// CrickFlow broadcast palette — navy, gold, and high-contrast whites.
class ScorebugTokens {
  const ScorebugTokens({
    required this.navy,
    required this.navyDeep,
    required this.blue,
    required this.gold,
    required this.white,
    required this.onScore,
    required this.liveRed,
    required this.opacity,
  });

  final Color navy;
  final Color navyDeep;
  final Color blue;
  final Color gold;
  final Color white;
  final Color onScore;
  final Color liveRed;
  final double opacity;

  factory ScorebugTokens.fromTheme(StreamOverlayTheme theme) {
    final primary = Color(theme.primaryColor);
    return ScorebugTokens(
      navy: primary.withValues(alpha: theme.opacity),
      navyDeep: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.35),
        primary.withValues(alpha: theme.opacity),
      ),
      blue: CfColors.primaryBlue.withValues(alpha: theme.opacity),
      gold: Color(theme.secondaryColor),
      white: Colors.white,
      onScore: const Color(0xFF0A1628),
      liveRed: CfColors.liveIndicator,
      opacity: theme.opacity,
    );
  }

  static const eventFour = Color(0xFF1565C0);
  static const eventSix = Color(0xFFFFA000);
  static const eventWicket = Color(0xFFC62828);
  static const eventNeutral = Color(0xFF37474F);
  static const eventReview = Color(0xFF6A1B9A);
  static const eventBreak = Color(0xFF455A64);
  static const eventResult = Color(0xFF0D47A1);
}

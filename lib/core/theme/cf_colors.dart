import 'package:flutter/material.dart';

/// Semantic palette registered on [ThemeData.extensions].
/// Use via `context.cf` — never hardcode surface/text colors in widgets.
@immutable
class CfColors extends ThemeExtension<CfColors> {
  const CfColors({
    required this.isLight,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.card,
    required this.sectionBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.textHint,
    required this.border,
    required this.chromeBackground,
    required this.chromeForeground,
    required this.navSelected,
    required this.navUnselected,
    required this.navIndicator,
    required this.link,
    required this.accent,
    required this.scoreEmphasis,
    required this.statusLive,
    required this.statusUpcoming,
    required this.statusCompleted,
    required this.success,
    required this.error,
    required this.info,
    required this.scoreboardBg,
    required this.onAccent,
    required this.onPrimary,
    required this.fabBackground,
    required this.fabForeground,
    required this.cardShadow,
    required this.appBarGradient,
    required this.heroGradient,
    required this.bannerScrimEnd,
  });

  final bool isLight;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color card;
  final Color sectionBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color textHint;
  final Color border;
  final Color chromeBackground;
  final Color chromeForeground;
  final Color navSelected;
  final Color navUnselected;
  final Color navIndicator;
  /// Links, text buttons, clickable labels.
  final Color link;
  /// Selected nav, chips, key actions — gold in dark, blue in light.
  final Color accent;
  /// Batting team / winner score emphasis — gold in dark, black in light.
  final Color scoreEmphasis;
  final Color statusLive;
  final Color statusUpcoming;
  final Color statusCompleted;
  final Color success;
  final Color error;
  final Color info;
  final Color scoreboardBg;
  final Color onAccent;
  final Color onPrimary;
  final Color fabBackground;
  final Color fabForeground;
  final Color cardShadow;
  final LinearGradient appBarGradient;
  final LinearGradient heroGradient;
  final Color bannerScrimEnd;

  /// Shared brand tokens — used for primary buttons in both themes.
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryBlueLight = Color(0xFF42A5F5);
  static const Color gold = Color(0xFFFFC107);
  static const Color goldDark = Color(0xFFFFA000);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentGreen = Color(0xFF43A047);
  static const Color liveIndicator = Color(0xFFE53935);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFC107), Color(0xFFFFA000)],
  );

  static const dark = CfColors(
    isLight: false,
    background: Color(0xFF0A0E17),
    surface: Color(0xFF141B2D),
    surfaceElevated: Color(0xFF1E2940),
    card: Color(0xFF1A2332),
    sectionBackground: Color(0xFF141B2D),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0BEC5),
    textMuted: Color(0xFF78909C),
    textDisabled: Color(0xFF78909C),
    textHint: Color(0xFF78909C),
    border: Color(0xFF2A3F5F),
    chromeBackground: Color(0xFF141B2D),
    chromeForeground: Color(0xFFFFFFFF),
    navSelected: gold,
    navUnselected: Color(0xFFB0BEC5),
    navIndicator: Color(0x402196F3),
    link: primaryBlueLight,
    accent: gold,
    scoreEmphasis: gold,
    statusLive: liveIndicator,
    statusUpcoming: gold,
    statusCompleted: primaryBlueLight,
    success: accentGreen,
    error: accentRed,
    info: primaryBlueLight,
    scoreboardBg: Color(0xFF0D47A1),
    onAccent: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    fabBackground: gold,
    fabForeground: Color(0xFF000000),
    cardShadow: Color(0x40000000),
    appBarGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1A2744), Color(0xFF141B2D)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0A0E17)],
    ),
    bannerScrimEnd: Color(0xBB0A0E17),
  );

  /// Professional sports-app light palette — Cricbuzz / CricHeroes inspired.
  static const light = CfColors(
    isLight: true,
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF2F4F7),
    card: Color(0xFFFFFFFF),
    sectionBackground: Color(0xFFFAFAFA),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF555555),
    textMuted: Color(0xFF888888),
    textDisabled: Color(0xFF888888),
    textHint: Color(0xFF999999),
    border: Color(0xFFE8EAED),
    chromeBackground: Color(0xFFFFFFFF),
    chromeForeground: Color(0xFF111111),
    navSelected: primaryBlue,
    navUnselected: Color(0xFF888888),
    navIndicator: Color(0x1A1E88E5),
    link: Color(0xFF1565C0),
    accent: primaryBlue,
    scoreEmphasis: Color(0xFF111111),
    statusLive: Color(0xFFD32F2F),
    statusUpcoming: Color(0xFFF57C00),
    statusCompleted: Color(0xFF757575),
    success: Color(0xFF2E7D32),
    error: Color(0xFFD32F2F),
    info: Color(0xFF1565C0),
    scoreboardBg: Color(0xFF0D47A1),
    onAccent: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    fabBackground: primaryBlue,
    fabForeground: Color(0xFFFFFFFF),
    cardShadow: Color(0x14000000),
    appBarGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF0D47A1)],
    ),
    bannerScrimEnd: Color(0x99000000),
  );

  /// Legacy alias — prefer [accent] or [scoreEmphasis].
  Color get onGold => onAccent;

  @override
  CfColors copyWith({
    bool? isLight,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? card,
    Color? sectionBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? textHint,
    Color? border,
    Color? chromeBackground,
    Color? chromeForeground,
    Color? navSelected,
    Color? navUnselected,
    Color? navIndicator,
    Color? link,
    Color? accent,
    Color? scoreEmphasis,
    Color? statusLive,
    Color? statusUpcoming,
    Color? statusCompleted,
    Color? success,
    Color? error,
    Color? info,
    Color? scoreboardBg,
    Color? onAccent,
    Color? onPrimary,
    Color? fabBackground,
    Color? fabForeground,
    Color? cardShadow,
    LinearGradient? appBarGradient,
    LinearGradient? heroGradient,
    Color? bannerScrimEnd,
  }) {
    return CfColors(
      isLight: isLight ?? this.isLight,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      card: card ?? this.card,
      sectionBackground: sectionBackground ?? this.sectionBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      textHint: textHint ?? this.textHint,
      border: border ?? this.border,
      chromeBackground: chromeBackground ?? this.chromeBackground,
      chromeForeground: chromeForeground ?? this.chromeForeground,
      navSelected: navSelected ?? this.navSelected,
      navUnselected: navUnselected ?? this.navUnselected,
      navIndicator: navIndicator ?? this.navIndicator,
      link: link ?? this.link,
      accent: accent ?? this.accent,
      scoreEmphasis: scoreEmphasis ?? this.scoreEmphasis,
      statusLive: statusLive ?? this.statusLive,
      statusUpcoming: statusUpcoming ?? this.statusUpcoming,
      statusCompleted: statusCompleted ?? this.statusCompleted,
      success: success ?? this.success,
      error: error ?? this.error,
      info: info ?? this.info,
      scoreboardBg: scoreboardBg ?? this.scoreboardBg,
      onAccent: onAccent ?? this.onAccent,
      onPrimary: onPrimary ?? this.onPrimary,
      fabBackground: fabBackground ?? this.fabBackground,
      fabForeground: fabForeground ?? this.fabForeground,
      cardShadow: cardShadow ?? this.cardShadow,
      appBarGradient: appBarGradient ?? this.appBarGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      bannerScrimEnd: bannerScrimEnd ?? this.bannerScrimEnd,
    );
  }

  @override
  CfColors lerp(ThemeExtension<CfColors>? other, double t) {
    if (other is! CfColors) return this;
    return CfColors(
      isLight: t < 0.5 ? isLight : other.isLight,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      card: Color.lerp(card, other.card, t)!,
      sectionBackground:
          Color.lerp(sectionBackground, other.sectionBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      border: Color.lerp(border, other.border, t)!,
      chromeBackground: Color.lerp(chromeBackground, other.chromeBackground, t)!,
      chromeForeground: Color.lerp(chromeForeground, other.chromeForeground, t)!,
      navSelected: Color.lerp(navSelected, other.navSelected, t)!,
      navUnselected: Color.lerp(navUnselected, other.navUnselected, t)!,
      navIndicator: Color.lerp(navIndicator, other.navIndicator, t)!,
      link: Color.lerp(link, other.link, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      scoreEmphasis: Color.lerp(scoreEmphasis, other.scoreEmphasis, t)!,
      statusLive: Color.lerp(statusLive, other.statusLive, t)!,
      statusUpcoming: Color.lerp(statusUpcoming, other.statusUpcoming, t)!,
      statusCompleted: Color.lerp(statusCompleted, other.statusCompleted, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      scoreboardBg: Color.lerp(scoreboardBg, other.scoreboardBg, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      fabBackground: Color.lerp(fabBackground, other.fabBackground, t)!,
      fabForeground: Color.lerp(fabForeground, other.fabForeground, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      appBarGradient: LinearGradient.lerp(appBarGradient, other.appBarGradient, t)!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
      bannerScrimEnd: Color.lerp(bannerScrimEnd, other.bannerScrimEnd, t)!,
    );
  }
}

extension CfColorsContext on BuildContext {
  CfColors get cf => Theme.of(this).extension<CfColors>() ?? CfColors.dark;
}

/// Shared card decoration for list/dashboard surfaces.
BoxDecoration cfCardDecoration(
  BuildContext context, {
  Color? color,
  Color? borderColor,
  double borderWidth = 1,
  List<BoxShadow>? boxShadow,
}) {
  final cf = context.cf;
  return BoxDecoration(
    color: color ?? cf.card,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: borderColor ?? cf.border, width: borderWidth),
    boxShadow: boxShadow ??
        [
          BoxShadow(
            color: cf.cardShadow,
            blurRadius: cf.isLight ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
  );
}

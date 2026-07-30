import 'package:flutter/material.dart';

/// CrickFlow brand tokens for admin SaaS dashboards.
@immutable
class AdminColors extends ThemeExtension<AdminColors> {
  const AdminColors({
    required this.isLight,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.sidebar,
    required this.sidebarHover,
    required this.sidebarFg,
    required this.sidebarFgMuted,
    required this.sidebarSelected,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.focusRing,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.rowHover,
    required this.rowAlt,
  });

  final bool isLight;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color sidebar;
  final Color sidebarHover;
  final Color sidebarFg;
  final Color sidebarFgMuted;
  final Color sidebarSelected;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color focusRing;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color rowHover;
  final Color rowAlt;

  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryBlueLight = Color(0xFF42A5F5);
  static const Color gold = Color(0xFFFFC107);
  static const Color goldDark = Color(0xFFFFA000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkGray = Color(0xFF263238);
  static const Color gray = Color(0xFF64748B);

  static const light = AdminColors(
    isLight: true,
    background: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    sidebar: Color(0xFF0F172A),
    sidebarHover: Color(0xFF1E293B),
    sidebarFg: Color(0xFFFFFFFF),
    sidebarFgMuted: Color(0x8AFFFFFF),
    sidebarSelected: gold,
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    focusRing: primaryBlue,
    success: Color(0xFF43A047),
    warning: Color(0xFFFFA000),
    error: Color(0xFFE53935),
    info: primaryBlue,
    rowHover: Color(0xFFF1F5F9),
    rowAlt: Color(0xFFF8FAFC),
  );

  static const dark = AdminColors(
    isLight: false,
    background: Color(0xFF0A0E17),
    surface: Color(0xFF141B2D),
    surfaceElevated: Color(0xFF1E2940),
    sidebar: Color(0xFF0A0E17),
    sidebarHover: Color(0xFF1A2332),
    sidebarFg: Color(0xFFFFFFFF),
    sidebarFgMuted: Color(0x8AFFFFFF),
    sidebarSelected: gold,
    card: Color(0xFF1A2332),
    border: Color(0xFF2A3F5F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0BEC5),
    textMuted: Color(0xFF90A4AE),
    focusRing: primaryBlueLight,
    success: Color(0xFF66BB6A),
    warning: gold,
    error: Color(0xFFEF5350),
    info: primaryBlueLight,
    rowHover: Color(0xFF1E2940),
    rowAlt: Color(0xFF121A28),
  );

  @override
  AdminColors copyWith({
    bool? isLight,
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? sidebar,
    Color? sidebarHover,
    Color? sidebarFg,
    Color? sidebarFgMuted,
    Color? sidebarSelected,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? focusRing,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? rowHover,
    Color? rowAlt,
  }) {
    return AdminColors(
      isLight: isLight ?? this.isLight,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      sidebar: sidebar ?? this.sidebar,
      sidebarHover: sidebarHover ?? this.sidebarHover,
      sidebarFg: sidebarFg ?? this.sidebarFg,
      sidebarFgMuted: sidebarFgMuted ?? this.sidebarFgMuted,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      focusRing: focusRing ?? this.focusRing,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      rowHover: rowHover ?? this.rowHover,
      rowAlt: rowAlt ?? this.rowAlt,
    );
  }

  @override
  AdminColors lerp(ThemeExtension<AdminColors>? other, double t) {
    if (other is! AdminColors) return this;
    return t < 0.5 ? this : other;
  }
}

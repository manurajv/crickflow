import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Scorecard-specific surfaces — registered on [ThemeData.extensions] so
/// light/dark switches stay centralized in [AppTheme].
@immutable
class ScorecardTheme extends ThemeExtension<ScorecardTheme> {
  const ScorecardTheme({
    required this.dataRowBackground,
    required this.sectionHeaderBackground,
    required this.inningsHeaderBackground,
    required this.inningsHeaderExpandedBackground,
    required this.summaryRowBackground,
  });

  /// Batter, bowler, fall-of-wicket, extras rows.
  final Color dataRowBackground;

  /// Column header band (Batters, Bowlers, etc.).
  final Color sectionHeaderBackground;

  /// Collapsed innings team header.
  final Color inningsHeaderBackground;

  /// Expanded innings team header.
  final Color inningsHeaderExpandedBackground;

  /// Total / emphasis summary band.
  final Color summaryRowBackground;

  static const dark = ScorecardTheme(
    dataRowBackground: AppColors.card,
    sectionHeaderBackground: AppColors.surface,
    inningsHeaderBackground: AppColors.surface,
    inningsHeaderExpandedBackground: AppColors.background,
    summaryRowBackground: AppColors.card,
  );

  /// Placeholder for future light theme — swap values in [AppTheme.lightTheme].
  static const light = ScorecardTheme(
    dataRowBackground: Color(0xFFF3F4F6),
    sectionHeaderBackground: Color(0xFFE8EAED),
    inningsHeaderBackground: Color(0xFFFFFFFF),
    inningsHeaderExpandedBackground: Color(0xFFE8EAED),
    summaryRowBackground: Color(0xFFF3F4F6),
  );

  @override
  ScorecardTheme copyWith({
    Color? dataRowBackground,
    Color? sectionHeaderBackground,
    Color? inningsHeaderBackground,
    Color? inningsHeaderExpandedBackground,
    Color? summaryRowBackground,
  }) {
    return ScorecardTheme(
      dataRowBackground: dataRowBackground ?? this.dataRowBackground,
      sectionHeaderBackground:
          sectionHeaderBackground ?? this.sectionHeaderBackground,
      inningsHeaderBackground:
          inningsHeaderBackground ?? this.inningsHeaderBackground,
      inningsHeaderExpandedBackground: inningsHeaderExpandedBackground ??
          this.inningsHeaderExpandedBackground,
      summaryRowBackground: summaryRowBackground ?? this.summaryRowBackground,
    );
  }

  @override
  ScorecardTheme lerp(ThemeExtension<ScorecardTheme>? other, double t) {
    if (other is! ScorecardTheme) return this;
    return ScorecardTheme(
      dataRowBackground:
          Color.lerp(dataRowBackground, other.dataRowBackground, t)!,
      sectionHeaderBackground:
          Color.lerp(sectionHeaderBackground, other.sectionHeaderBackground, t)!,
      inningsHeaderBackground:
          Color.lerp(inningsHeaderBackground, other.inningsHeaderBackground, t)!,
      inningsHeaderExpandedBackground: Color.lerp(
        inningsHeaderExpandedBackground,
        other.inningsHeaderExpandedBackground,
        t,
      )!,
      summaryRowBackground:
          Color.lerp(summaryRowBackground, other.summaryRowBackground, t)!,
    );
  }
}

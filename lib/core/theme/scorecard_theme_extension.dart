import 'package:flutter/material.dart';

/// Scorecard-specific surfaces — registered on [ThemeData.extensions].
@immutable
class ScorecardTheme extends ThemeExtension<ScorecardTheme> {
  const ScorecardTheme({
    required this.dataRowBackground,
    required this.sectionHeaderBackground,
    required this.inningsHeaderBackground,
    required this.inningsHeaderExpandedBackground,
    required this.summaryRowBackground,
  });

  final Color dataRowBackground;
  final Color sectionHeaderBackground;
  final Color inningsHeaderBackground;
  final Color inningsHeaderExpandedBackground;
  final Color summaryRowBackground;

  static const dark = ScorecardTheme(
    dataRowBackground: Color(0xFF1A2332),
    sectionHeaderBackground: Color(0xFF141B2D),
    inningsHeaderBackground: Color(0xFF141B2D),
    inningsHeaderExpandedBackground: Color(0xFF0A0E17),
    summaryRowBackground: Color(0xFF1A2332),
  );

  /// Clean white/grey scorecard rows for light mode.
  static const light = ScorecardTheme(
    dataRowBackground: Color(0xFFFFFFFF),
    sectionHeaderBackground: Color(0xFFF2F4F7),
    inningsHeaderBackground: Color(0xFFFFFFFF),
    inningsHeaderExpandedBackground: Color(0xFFFAFAFA),
    summaryRowBackground: Color(0xFFF2F4F7),
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

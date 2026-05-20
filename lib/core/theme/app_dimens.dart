import 'package:flutter/material.dart';

/// Compact layout tokens — use across screens for a denser, modern UI.
class AppDimens {
  AppDimens._();

  // Spacing
  static const double spaceXs = 4;
  static const double spaceSm = 6;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;

  // Radii
  static const double radiusSm = 8;
  static const double radiusMd = 10;
  static const double radiusLg = 12;

  // Form fields (reference underline style)
  static const double fieldPaddingVertical = 18;
  static const double fieldPaddingVerticalCompact = 14;
  static const double fieldSpacing = 20;
  static const double fontInput = 16;

  // Controls
  static const double buttonHeight = 40;
  static const double buttonHeightDense = 36;
  static const double buttonHeightLarge = 52;
  static const double runButtonSize = 44;
  static const double appBarHeight = 48;
  static const double bottomNavHeight = 60;

  // Icons
  static const double iconSm = 18;
  static const double iconMd = 20;
  static const double iconLg = 22;

  // Typography (when not using TextTheme)
  static const double fontDisplay = 26;
  static const double fontHeadline = 18;
  static const double fontTitle = 16;
  static const double fontBody = 14;
  static const double fontCaption = 12;
  static const double fontScoreLarge = 24;
  static const double fontScoreMedium = 20;

  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceSm);
  static const EdgeInsets cardPadding = EdgeInsets.all(spaceMd);
  static const EdgeInsets listPadding =
      EdgeInsets.fromLTRB(spaceMd, spaceSm, spaceMd, spaceXl);

  static BorderRadius get cardRadius => BorderRadius.circular(radiusLg);
  static BorderRadius get buttonRadius => BorderRadius.circular(radiusMd);
}

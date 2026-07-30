import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';

/// Spacing, radius, layout, and icon size tokens for the admin design system.
///
/// Prefer these over hardcoded numbers in new UI. Existing modules may migrate
/// opportunistically — do not force a redesign.
@immutable
class AdminDimens extends ThemeExtension<AdminDimens> {
  const AdminDimens({
    this.spaceXs = 4,
    this.spaceSm = 8,
    this.spaceMd = 12,
    this.spaceLg = 16,
    this.spaceXl = 20,
    this.spaceXxl = 24,
    this.spaceXxxl = 32,
    this.radiusSm = 8,
    this.radiusMd = 12,
    this.radiusLg = 16,
    this.radiusXl = 20,
    this.radiusPill = 999,
    this.topBarHeight = 64,
    this.detailPanelWidth = 480,
    this.pagePadding = const EdgeInsets.fromLTRB(20, 20, 20, 32),
    this.cardPadding = const EdgeInsets.all(20),
    this.tableCellPadding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 14,
    ),
    this.iconSm = 16,
    this.iconMd = 18,
    this.iconLg = 22,
    this.iconXl = 32,
  });

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceXxl;
  final double spaceXxxl;

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusPill;

  final double topBarHeight;
  final double detailPanelWidth;
  final EdgeInsets pagePadding;
  final EdgeInsets cardPadding;
  final EdgeInsets tableCellPadding;

  final double iconSm;
  final double iconMd;
  final double iconLg;
  final double iconXl;

  double get sidebarExpanded => Breakpoints.sidebarExpanded;
  double get sidebarCollapsed => Breakpoints.sidebarCollapsed;

  static const standard = AdminDimens();

  SizedBox get gapXs => SizedBox(height: spaceXs, width: spaceXs);
  SizedBox get gapSm => SizedBox(height: spaceSm, width: spaceSm);
  SizedBox get gapMd => SizedBox(height: spaceMd, width: spaceMd);
  SizedBox get gapLg => SizedBox(height: spaceLg, width: spaceLg);
  SizedBox get gapXl => SizedBox(height: spaceXl, width: spaceXl);

  BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);

  @override
  AdminDimens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? spaceXxxl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusPill,
    double? topBarHeight,
    double? detailPanelWidth,
    EdgeInsets? pagePadding,
    EdgeInsets? cardPadding,
    EdgeInsets? tableCellPadding,
    double? iconSm,
    double? iconMd,
    double? iconLg,
    double? iconXl,
  }) {
    return AdminDimens(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      spaceXxxl: spaceXxxl ?? this.spaceXxxl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusPill: radiusPill ?? this.radiusPill,
      topBarHeight: topBarHeight ?? this.topBarHeight,
      detailPanelWidth: detailPanelWidth ?? this.detailPanelWidth,
      pagePadding: pagePadding ?? this.pagePadding,
      cardPadding: cardPadding ?? this.cardPadding,
      tableCellPadding: tableCellPadding ?? this.tableCellPadding,
      iconSm: iconSm ?? this.iconSm,
      iconMd: iconMd ?? this.iconMd,
      iconLg: iconLg ?? this.iconLg,
      iconXl: iconXl ?? this.iconXl,
    );
  }

  @override
  AdminDimens lerp(ThemeExtension<AdminDimens>? other, double t) {
    if (other is! AdminDimens) return this;
    return t < 0.5 ? this : other;
  }
}

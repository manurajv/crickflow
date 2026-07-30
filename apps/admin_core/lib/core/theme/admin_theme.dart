import 'package:flutter/material.dart';

import 'admin_colors.dart';
import 'admin_dimens.dart';
import 'admin_elevations.dart';
import 'admin_typography.dart';

/// Material 3 premium SaaS theme (CrickFlow blue / gold / white / dark gray).
abstract final class AdminTheme {
  static ThemeData light() => _build(Brightness.light, AdminColors.light);

  static ThemeData dark() => _build(Brightness.dark, AdminColors.dark);

  static ThemeData _build(Brightness brightness, AdminColors colors) {
    final isDark = brightness == Brightness.dark;
    const dimens = AdminDimens.standard;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AdminColors.primaryBlue,
      brightness: brightness,
      primary: AdminColors.primaryBlue,
      secondary: AdminColors.gold,
      onSecondary: AdminColors.darkGray,
      surface: colors.surface,
      error: colors.error,
    );

    final textTheme = AdminTypography.textTheme(base.textTheme, colors);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors, dimens],
      focusColor: colors.focusRing.withValues(alpha: 0.18),
      hoverColor: colors.rowHover.withValues(alpha: isDark ? 0.5 : 1),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: AdminElevations.appBar,
        scrolledUnderElevation: 0.5,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: isDark ? AdminElevations.cardDark : AdminElevations.card,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: dimens.borderRadiusLg,
          side: BorderSide(color: colors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: colors.border, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colors.surfaceElevated : colors.background,
        border: OutlineInputBorder(
          borderRadius: dimens.borderRadiusMd,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: dimens.borderRadiusMd,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: dimens.borderRadiusMd,
          borderSide: BorderSide(color: colors.focusRing, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: dimens.borderRadiusMd,
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: dimens.borderRadiusMd,
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: dimens.spaceLg,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        helperStyle: textTheme.bodySmall?.copyWith(color: colors.textMuted),
        errorStyle: textTheme.bodySmall?.copyWith(color: colors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.textMuted,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: dimens.spaceXl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusMd),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          padding: EdgeInsets.symmetric(
            horizontal: dimens.spaceXl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusMd),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.primaryBlue,
          padding: EdgeInsets.symmetric(
            horizontal: dimens.spaceLg,
            vertical: dimens.spaceMd,
          ),
          shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusMd),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceElevated,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusSm),
        labelStyle: textTheme.labelMedium,
        padding: EdgeInsets.symmetric(horizontal: dimens.spaceSm),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: AdminElevations.overlay,
        shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusXl),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: AdminElevations.snackbar,
        backgroundColor: isDark ? colors.surfaceElevated : colors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusMd),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceElevated : colors.textPrimary,
          borderRadius: dimens.borderRadiusSm,
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        elevation: AdminElevations.overlay,
        shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusMd),
        textStyle: textTheme.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: dimens.spaceLg),
        shape: RoundedRectangleBorder(borderRadius: dimens.borderRadiusMd),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(8),
        thumbColor: WidgetStatePropertyAll(
          colors.textMuted.withValues(alpha: 0.45),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AdminColors.primaryBlue,
        linearTrackColor: colors.border,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_dimens.dart';
import 'cf_colors.dart';
import 'cf_input_theme.dart';
import 'scorecard_theme_extension.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        cf: CfColors.light,
        scorecard: ScorecardTheme.light,
        overlayStyle: SystemUiOverlayStyle.dark,
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        cf: CfColors.dark,
        scorecard: ScorecardTheme.dark,
        overlayStyle: SystemUiOverlayStyle.light,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required CfColors cf,
    required ScorecardTheme scorecard,
    required SystemUiOverlayStyle overlayStyle,
  }) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: CfColors.primaryBlue,
            secondary: CfColors.gold,
            error: cf.error,
            surface: cf.surface,
            onPrimary: cf.onPrimary,
            onSecondary: cf.onAccent,
            onSurface: cf.textPrimary,
            onSurfaceVariant: cf.textSecondary,
            outline: cf.border,
            surfaceContainerLowest: cf.background,
            surfaceContainerLow: cf.card,
            surfaceContainer: cf.surfaceElevated,
            surfaceContainerHigh: cf.surfaceElevated,
            surfaceContainerHighest: cf.card,
          )
        : ColorScheme.light(
            primary: CfColors.primaryBlue,
            secondary: CfColors.primaryBlue,
            error: cf.error,
            surface: cf.surface,
            onPrimary: cf.onPrimary,
            onSecondary: cf.onPrimary,
            onSurface: cf.textPrimary,
            onSurfaceVariant: cf.textSecondary,
            outline: cf.border,
            surfaceContainerLowest: cf.background,
            surfaceContainerLow: cf.card,
            surfaceContainer: cf.surfaceElevated,
            surfaceContainerHigh: cf.surfaceElevated,
            surfaceContainerHighest: cf.card,
          );

    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontSize: AppDimens.fontDisplay,
        fontWeight: FontWeight.bold,
        color: cf.textPrimary,
        height: 1.15,
      ),
      displayMedium: TextStyle(
        fontSize: AppDimens.fontScoreLarge,
        fontWeight: FontWeight.bold,
        color: cf.textPrimary,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: AppDimens.fontHeadline,
        fontWeight: FontWeight.w600,
        color: cf.textPrimary,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: AppDimens.fontTitle,
        fontWeight: FontWeight.w600,
        color: cf.textPrimary,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontSize: AppDimens.fontBody,
        fontWeight: FontWeight.w600,
        color: cf.textPrimary,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        fontSize: AppDimens.fontBody,
        color: cf.textPrimary,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        fontSize: AppDimens.fontCaption,
        color: cf.textSecondary,
        height: 1.35,
      ),
      bodySmall: TextStyle(
        fontSize: 11,
        color: cf.textMuted,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        fontSize: AppDimens.fontCaption,
        fontWeight: FontWeight.w600,
        color: isDark ? CfColors.gold : cf.link,
        letterSpacing: 0.2,
      ),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: AppDimens.buttonRadius,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cf.background,
      textTheme: textTheme,
      iconTheme: IconThemeData(size: AppDimens.iconMd, color: cf.textPrimary),
      primaryIconTheme: IconThemeData(size: AppDimens.iconMd, color: cf.onPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: cf.chromeBackground,
        foregroundColor: cf.chromeForeground,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 0,
        scrolledUnderElevation: isDark ? 0 : 0.5,
        centerTitle: true,
        toolbarHeight: AppDimens.appBarHeight,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(
          size: AppDimens.iconMd,
          color: cf.chromeForeground,
        ),
        actionsIconTheme: IconThemeData(
          size: AppDimens.iconMd,
          color: cf.chromeForeground,
        ),
        systemOverlayStyle: overlayStyle,
        shape: Border(
          bottom: BorderSide(color: cf.border, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: cf.card,
        elevation: isDark ? 2 : 0,
        shadowColor: cf.cardShadow,
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimens.cardRadius,
          side: BorderSide(color: cf.border, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        minLeadingWidth: 28,
        horizontalTitleGap: AppDimens.spaceSm,
        dense: true,
        visualDensity: VisualDensity(horizontal: 0, vertical: -2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CfColors.primaryBlue,
          foregroundColor: cf.onPrimary,
          minimumSize: const Size(64, AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceSm,
          ),
          textStyle: textTheme.titleMedium,
          shape: buttonShape,
          elevation: isDark ? 1 : 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? CfColors.primaryBlue : cf.textPrimary,
          backgroundColor: isDark ? null : cf.card,
          minimumSize: const Size(64, AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceSm,
          ),
          textStyle: textTheme.titleMedium,
          side: BorderSide(
            color: isDark ? CfColors.primaryBlue : cf.border,
            width: 1,
          ),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cf.link,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceXs,
          ),
          textStyle: textTheme.titleMedium,
          minimumSize: const Size(48, AppDimens.buttonHeightDense),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppDimens.buttonHeight),
          textStyle: textTheme.titleMedium,
          shape: buttonShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cf.fabBackground,
        foregroundColor: cf.fabForeground,
        extendedSizeConstraints: const BoxConstraints(
          minHeight: AppDimens.buttonHeight,
          minWidth: 48,
        ),
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        extendedTextStyle:
            textTheme.titleMedium?.copyWith(color: cf.fabForeground),
      ),
      inputDecorationTheme: CfInputTheme.decorationTheme(textTheme, cf),
      chipTheme: ChipThemeData(
        backgroundColor: cf.surfaceElevated,
        labelStyle: textTheme.bodyMedium!.copyWith(color: cf.textSecondary),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
        side: BorderSide(color: cf.border),
        shape: RoundedRectangleBorder(borderRadius: AppDimens.buttonRadius),
      ),
      dividerTheme: DividerThemeData(
        color: cf.border,
        space: 1,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cf.surface,
        selectedItemColor: cf.navSelected,
        unselectedItemColor: cf.navUnselected,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        selectedIconTheme: const IconThemeData(size: AppDimens.iconMd),
        unselectedIconTheme: const IconThemeData(size: AppDimens.iconSm),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cf.chromeBackground,
        indicatorColor: cf.navIndicator,
        elevation: isDark ? 0 : 0,
        height: AppDimens.bottomNavHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? cf.navSelected : cf.navUnselected,
            size: selected ? AppDimens.iconMd : AppDimens.iconSm,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: selected ? 11 : 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? cf.navSelected : cf.navUnselected,
          );
        }),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cf.surface,
        elevation: isDark ? 8 : 2,
        shadowColor: cf.cardShadow,
        shape: RoundedRectangleBorder(borderRadius: AppDimens.cardRadius),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cf.surface,
        elevation: isDark ? 8 : 2,
        shadowColor: cf.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusLg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? cf.surfaceElevated : cf.textPrimary,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: isDark ? cf.textPrimary : cf.card,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppDimens.buttonRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        strokeWidth: 2,
        color: cf.accent,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceXs,
            ),
          ),
          textStyle: WidgetStateProperty.all(textTheme.bodyMedium),
        ),
      ),
      extensions: [cf, scorecard],
    );
  }
}

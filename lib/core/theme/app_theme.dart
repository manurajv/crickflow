import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_dimens.dart';
import 'cf_input_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primaryBlue,
      secondary: AppColors.gold,
      error: AppColors.accentRed,
      surface: AppColors.surface,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: AppColors.textPrimary,
    );

    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontSize: AppDimens.fontDisplay,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.15,
      ),
      displayMedium: TextStyle(
        fontSize: AppDimens.fontScoreLarge,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: AppDimens.fontHeadline,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: AppDimens.fontTitle,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontSize: AppDimens.fontBody,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        fontSize: AppDimens.fontBody,
        color: AppColors.textPrimary,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        fontSize: AppDimens.fontCaption,
        color: AppColors.textSecondary,
        height: 1.35,
      ),
      bodySmall: TextStyle(
        fontSize: 11,
        color: AppColors.textMuted,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        fontSize: AppDimens.fontCaption,
        fontWeight: FontWeight.w600,
        color: AppColors.gold,
        letterSpacing: 0.2,
      ),
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: AppDimens.buttonRadius,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      iconTheme: const IconThemeData(size: AppDimens.iconMd),
      primaryIconTheme: const IconThemeData(size: AppDimens.iconMd),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.chromeBackground,
        foregroundColor: AppColors.chromeForeground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: AppDimens.appBarHeight,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(
          size: AppDimens.iconMd,
          color: AppColors.chromeForeground,
        ),
        actionsIconTheme: const IconThemeData(
          size: AppDimens.iconMd,
          color: AppColors.chromeForeground,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 2,
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppDimens.cardRadius,
          side: const BorderSide(color: AppColors.border, width: 0.5),
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
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceSm,
          ),
          textStyle: textTheme.titleMedium,
          shape: buttonShape,
          elevation: 1,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlueLight,
          minimumSize: const Size(64, AppDimens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceLg,
            vertical: AppDimens.spaceSm,
          ),
          textStyle: textTheme.titleMedium,
          side: const BorderSide(color: AppColors.primaryBlue),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlueLight,
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
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        extendedSizeConstraints: const BoxConstraints(
          minHeight: AppDimens.buttonHeight,
          minWidth: 48,
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        extendedTextStyle: textTheme.titleMedium?.copyWith(color: Colors.black),
      ),
      inputDecorationTheme: CfInputTheme.decorationTheme(textTheme),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: textTheme.bodyMedium!,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: AppDimens.buttonRadius),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        space: 1,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        selectedIconTheme: const IconThemeData(size: AppDimens.iconMd),
        unselectedIconTheme: const IconThemeData(size: AppDimens.iconSm),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.chromeBackground,
        indicatorColor: AppColors.navIndicator,
        elevation: 0,
        height: AppDimens.bottomNavHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.navSelected : AppColors.navUnselected,
            size: selected ? AppDimens.iconMd : AppDimens.iconSm,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: selected ? 11 : 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.navSelected : AppColors.navUnselected,
          );
        }),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppDimens.cardRadius),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusLg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: textTheme.bodyLarge,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppDimens.buttonRadius),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        strokeWidth: 2,
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
    );
  }
}

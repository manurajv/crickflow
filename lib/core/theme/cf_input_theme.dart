import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimens.dart';

/// Reference-style underline text fields used app-wide.
class CfInputTheme {
  CfInputTheme._();

  static const double fieldFontSize = 16;
  static const double labelFontSize = 15;
  static const EdgeInsets fieldPadding =
      EdgeInsets.symmetric(vertical: AppDimens.fieldPaddingVertical);

  static InputDecorationTheme decorationTheme(TextTheme textTheme) {
    final labelStyle = textTheme.bodyLarge?.copyWith(
      color: AppColors.textSecondary,
      fontSize: labelFontSize,
    );
    final hintStyle = textTheme.bodyLarge?.copyWith(
      color: AppColors.textMuted,
      fontSize: fieldFontSize,
    );

    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.border),
    );
    const underlineFocused = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.gold, width: 2),
    );
    const underlineError = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.accentRed),
    );

    return InputDecorationTheme(
      filled: false,
      isDense: false,
      contentPadding: fieldPadding,
      labelStyle: labelStyle,
      hintStyle: hintStyle,
      floatingLabelStyle: labelStyle?.copyWith(color: AppColors.gold),
      border: underline,
      enabledBorder: underline,
      focusedBorder: underlineFocused,
      errorBorder: underlineError,
      focusedErrorBorder: underlineError,
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
    );
  }

  static TextStyle fieldTextStyle(TextTheme textTheme) => textTheme.bodyLarge!.copyWith(
        fontSize: fieldFontSize,
        height: 1.35,
      );

  /// Smaller underline for filter bars / quick search rows.
  static InputDecorationTheme compactDecorationTheme(TextTheme textTheme) {
    return decorationTheme(textTheme).copyWith(
      contentPadding: const EdgeInsets.symmetric(
        vertical: AppDimens.fieldPaddingVerticalCompact,
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }
}

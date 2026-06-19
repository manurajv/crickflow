import 'package:flutter/material.dart';
import 'app_dimens.dart';
import 'cf_colors.dart';

/// Reference-style underline text fields used app-wide.
class CfInputTheme {
  CfInputTheme._();

  static const double fieldFontSize = 16;
  static const double labelFontSize = 15;
  static const EdgeInsets fieldPadding =
      EdgeInsets.symmetric(vertical: AppDimens.fieldPaddingVertical);

  static InputDecorationTheme decorationTheme(
    TextTheme textTheme,
    CfColors cf,
  ) {
    final labelStyle = textTheme.bodyLarge?.copyWith(
      color: cf.textSecondary,
      fontSize: labelFontSize,
    );
    final hintStyle = textTheme.bodyLarge?.copyWith(
      color: cf.textHint,
      fontSize: fieldFontSize,
    );

    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: cf.border),
    );
    final underlineFocused = UnderlineInputBorder(
      borderSide: BorderSide(color: cf.accent, width: 2),
    );
    final underlineError = UnderlineInputBorder(
      borderSide: BorderSide(color: cf.error),
    );

    return InputDecorationTheme(
      filled: false,
      isDense: false,
      contentPadding: fieldPadding,
      labelStyle: labelStyle,
      hintStyle: hintStyle,
      floatingLabelStyle: labelStyle?.copyWith(color: cf.accent),
      border: underline,
      enabledBorder: underline,
      focusedBorder: underlineFocused,
      errorBorder: underlineError,
      focusedErrorBorder: underlineError,
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: cf.border.withValues(alpha: 0.5)),
      ),
    );
  }

  static TextStyle fieldTextStyle(TextTheme textTheme) =>
      textTheme.bodyLarge!.copyWith(
        fontSize: fieldFontSize,
        height: 1.35,
      );

  static InputDecorationTheme compactDecorationTheme(
    TextTheme textTheme,
    CfColors cf,
  ) {
    return decorationTheme(textTheme, cf).copyWith(
      contentPadding: const EdgeInsets.symmetric(
        vertical: AppDimens.fieldPaddingVerticalCompact,
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: cf.textSecondary,
      ),
    );
  }
}

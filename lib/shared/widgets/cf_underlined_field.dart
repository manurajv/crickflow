import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Full-width underline inputs (reference-style), larger than default compact theme.
class CfUnderlinedField extends StatelessWidget {
  const CfUnderlinedField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.required = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final Widget? prefix;
  final int maxLines;
  final bool enabled;

  static InputDecoration decoration(
    BuildContext context, {
    String? label,
    String? hint,
    bool required = false,
    Widget? suffix,
    Widget? prefix,
  }) {
    final theme = Theme.of(context);
    final labelText = label == null
        ? null
        : required
            ? '$label *'
            : label;

    return InputDecoration(
      labelText: labelText,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: false,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      labelStyle: theme.textTheme.bodyLarge?.copyWith(
        color: AppColors.textSecondary,
        fontSize: 15,
      ),
      hintStyle: theme.textTheme.bodyLarge?.copyWith(
        color: AppColors.textMuted,
        fontSize: 16,
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.gold, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accentRed),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accentRed, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.35,
        );

    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      enabled: enabled,
      style: style,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: decoration(
        context,
        label: label,
        hint: hint,
        required: required,
        suffix: suffix,
        prefix: prefix,
      ),
    );
  }
}

/// Vertical spacing between underline fields on team forms.
class CfFormFieldGroup extends StatelessWidget {
  const CfFormFieldGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimens.spaceLg),
          children[i],
        ],
      ],
    );
  }
}

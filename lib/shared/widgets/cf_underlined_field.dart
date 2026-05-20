import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_input_theme.dart';

/// Full-width underline text field — uses global [CfInputTheme].
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
    this.onTap,
    this.readOnly = false,
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
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? suffix;
  final Widget? prefix;
  final int maxLines;
  final bool enabled;

  static String? labelWithRequired(String? label, bool required) {
    if (label == null) return null;
    return required ? '$label *' : label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      style: CfInputTheme.fieldTextStyle(theme.textTheme),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: labelWithRequired(label, required),
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
      ).applyDefaults(theme.inputDecorationTheme),
    );
  }
}

/// Vertical spacing between underline fields.
class CfFormFieldGroup extends StatelessWidget {
  const CfFormFieldGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimens.fieldSpacing),
          children[i],
        ],
      ],
    );
  }
}

/// Section label for multi-field forms.
class CfFormSectionTitle extends StatelessWidget {
  const CfFormSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

/// Tappable underline row for date/time pickers.
class CfPickerField extends StatelessWidget {
  const CfPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
    this.icon = Icons.event,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool required;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CfUnderlinedField(
      label: label,
      required: required,
      initialValue: value,
      readOnly: true,
      onTap: onTap,
      suffix: Icon(icon, color: AppColors.primaryBlueLight, size: 22),
    );
  }
}

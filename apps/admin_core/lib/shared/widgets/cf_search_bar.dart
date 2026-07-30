import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';

class CfSearchBar extends StatelessWidget {
  const CfSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    return Semantics(
      textField: true,
      label: hintText,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(
            Icons.search,
            color: colors.textMuted,
            size: dimens.iconLg,
          ),
          suffixIcon: controller == null
              ? null
              : ListenableBuilder(
                  listenable: controller!,
                  builder: (context, _) {
                    if (controller!.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller!.clear();
                        onClear?.call();
                        onChanged?.call('');
                      },
                      icon: Icon(Icons.close, size: dimens.iconMd),
                    );
                  },
                ),
          isDense: true,
        ),
      ),
    );
  }
}

/// Compact filter / search chip for toolbars.
class CfSearchChip extends StatelessWidget {
  const CfSearchChip({
    super.key,
    required this.label,
    this.onDeleted,
    this.selected = false,
    this.onSelected,
  });

  final String label;
  final VoidCallback? onDeleted;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      onDeleted: onDeleted,
      deleteIcon: onDeleted == null ? null : const Icon(Icons.close, size: 14),
    );
  }
}

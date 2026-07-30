import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';

class CfCard extends StatelessWidget {
  const CfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final radius = BorderRadius.circular(16);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(color: colors.border),
    );

    final content = Padding(padding: padding, child: child);

    // Use Material (not DecoratedBox) as the colored surface so nested
    // ListTile / SwitchListTile ink splashes paint onto this ancestor.
    if (onTap == null) {
      return Material(
        color: colors.card,
        elevation: colors.isLight ? 1.5 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return Material(
      color: colors.card,
      elevation: colors.isLight ? 1.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

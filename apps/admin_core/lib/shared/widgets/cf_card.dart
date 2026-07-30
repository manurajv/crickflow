import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/admin_elevations.dart';
import '../../core/theme/admin_motion.dart';

enum CfCardVariant { standard, stat, info, action, list }

class CfCard extends StatefulWidget {
  const CfCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.variant = CfCardVariant.standard,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final CfCardVariant variant;
  final String? semanticLabel;

  @override
  State<CfCard> createState() => _CfCardState();
}

class _CfCardState extends State<CfCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    final radius = dimens.borderRadiusLg;
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(color: colors.border),
    );
    final padding = widget.padding ??
        (widget.variant == CfCardVariant.list
            ? EdgeInsets.zero
            : dimens.cardPadding);

    final elevation = colors.isLight
        ? (_hovered && widget.onTap != null
            ? AdminElevations.cardHover
            : AdminElevations.card)
        : AdminElevations.cardDark;

    final content = Padding(padding: padding, child: widget.child);

    Widget card = AnimatedContainer(
      duration: AdminMotion.fast,
      curve: AdminMotion.standard,
      child: Material(
        color: colors.card,
        elevation: elevation,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: widget.onTap == null
            ? content
            : InkWell(
                onTap: widget.onTap,
                borderRadius: radius,
                hoverColor: colors.rowHover.withValues(alpha: 0.55),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hovered = true),
                  onExit: (_) => setState(() => _hovered = false),
                  child: content,
                ),
              ),
      ),
    );

    if (widget.semanticLabel != null) {
      card = Semantics(label: widget.semanticLabel, container: true, child: card);
    }
    return card;
  }
}

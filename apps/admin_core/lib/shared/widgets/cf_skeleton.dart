import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/admin_motion.dart';
import 'cf_card.dart';

/// Shimmer block used by skeleton loaders.
class CfSkeletonBox extends StatefulWidget {
  const CfSkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<CfSkeletonBox> createState() => _CfSkeletonBoxState();
}

class _CfSkeletonBoxState extends State<CfSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: _controller,
          curve: AdminMotion.standard,
        ).value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? dimens.borderRadiusSm,
            color: Color.lerp(
              colors.border.withValues(alpha: 0.35),
              colors.border.withValues(alpha: 0.75),
              t,
            ),
          ),
        );
      },
    );
  }
}

class CfSkeletonCard extends StatelessWidget {
  const CfSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final dimens = context.adminDimens;
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CfSkeletonBox(width: 40, height: 40, borderRadius: dimens.borderRadiusMd),
          SizedBox(height: dimens.spaceLg),
          const CfSkeletonBox(width: 80, height: 22),
          SizedBox(height: dimens.spaceSm),
          const CfSkeletonBox(width: 120, height: 12),
        ],
      ),
    );
  }
}

class CfSkeletonTable extends StatelessWidget {
  const CfSkeletonTable({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dimens = context.adminDimens;
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: dimens.tableCellPadding,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(dimens.radiusLg),
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) SizedBox(width: dimens.spaceLg),
                  const Expanded(child: CfSkeletonBox(height: 12)),
                ],
              ],
            ),
          ),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: dimens.tableCellPadding,
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) SizedBox(width: dimens.spaceLg),
                    const Expanded(child: CfSkeletonBox(height: 12)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class CfSkeletonPage extends StatelessWidget {
  const CfSkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dimens = context.adminDimens;
    return Padding(
      padding: dimens.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) SizedBox(width: dimens.spaceMd),
                const Expanded(child: CfSkeletonCard()),
              ],
            ],
          ),
          SizedBox(height: dimens.spaceXl),
          const Expanded(child: CfSkeletonTable()),
        ],
      ),
    );
  }
}

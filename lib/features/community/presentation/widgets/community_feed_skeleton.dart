import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';

class CommunityFeedSkeleton extends StatelessWidget {
  const CommunityFeedSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: AppDimens.listPadding,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimens.spaceSm),
      itemBuilder: (_, _) => Container(
        padding: AppDimens.cardPadding,
        decoration: BoxDecoration(
          color: cf.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cf.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _box(cf, 40, 40, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _box(cf, 120, 12),
                      const SizedBox(height: 6),
                      _box(cf, 80, 10),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _box(cf, double.infinity, 14),
            const SizedBox(height: 8),
            _box(cf, 220, 12),
            const SizedBox(height: 12),
            _box(cf, double.infinity, 160, radius: 12),
            const SizedBox(height: 12),
            Row(
              children: [
                _box(cf, 48, 12),
                const SizedBox(width: 16),
                _box(cf, 48, 12),
                const SizedBox(width: 16),
                _box(cf, 48, 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(CfColors cf, double w, double h, {double radius = 6}) {
    return Container(
      width: w == double.infinity ? null : w,
      height: h,
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

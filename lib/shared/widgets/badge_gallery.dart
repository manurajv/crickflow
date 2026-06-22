import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../data/models/badge_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../providers/badge_provider.dart';

class BadgeGallery extends ConsumerWidget {
  const BadgeGallery({super.key, required this.badgeIds});

  final List<String> badgeIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (badgeIds.isEmpty) {
      return Text(
        'No badges yet — play matches to earn them.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final badgesAsync = ref.watch(userBadgesProvider(badgeIds));

    return badgesAsync.when(
      data: (badges) {
        if (badges.isEmpty) {
          return Text(
            '${badgeIds.length} badge(s) on record',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Wrap(
          spacing: AppDimens.spaceSm,
          runSpacing: AppDimens.spaceSm,
          children: badges.map((b) => _BadgeChip(badge: b)).toList(),
        );
      },
      loading: () => const SizedBox(
        height: 32,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final BadgeModel badge;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(_iconFor(badge.type), size: 16, color: AppColors.gold),
      label: Text(badge.title),
    );
  }

  IconData _iconFor(BadgeType type) {
    return switch (type) {
      BadgeType.batting => Icons.sports_cricket,
      BadgeType.bowling => Icons.sports_baseball,
      BadgeType.fielding => Icons.back_hand,
      BadgeType.captaincy => Icons.military_tech_outlined,
      BadgeType.career => Icons.timeline,
      BadgeType.milestone => Icons.flag,
      BadgeType.special => Icons.auto_awesome,
      BadgeType.team => Icons.groups,
      BadgeType.matchHero => Icons.star,
    };
  }
}

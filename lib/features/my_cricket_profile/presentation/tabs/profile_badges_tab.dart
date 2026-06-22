import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../badge_detail_screen.dart';

class ProfileBadgesTab extends StatefulWidget {
  const ProfileBadgesTab({super.key, required this.badges});

  final List<PlayerBadgeProgress> badges;

  @override
  State<ProfileBadgesTab> createState() => _ProfileBadgesTabState();
}

class _ProfileBadgesTabState extends State<ProfileBadgesTab> {
  BadgeType? _category;
  static const _pageSize = 24;
  var _visible = 24;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    var list = widget.badges;
    if (_category != null) {
      list = list.where((b) => b.definition.category == _category).toList();
    }
    list = list.toList()
      ..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        if (a.isRepeatable && b.isRepeatable && a.unlockCount != b.unlockCount) {
          return b.unlockCount.compareTo(a.unlockCount);
        }
        if (a.isOneTime &&
            b.isOneTime &&
            a.unlocked &&
            b.unlocked &&
            a.unlockedAt != null &&
            b.unlockedAt != null) {
          return b.unlockedAt!.compareTo(a.unlockedAt!);
        }
        return b.completionPct.compareTo(a.completionPct);
      });

    final unlocked = widget.badges.where((b) => b.unlocked).length;
    final page = list.take(_visible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: Text(
            '$unlocked / ${widget.badges.length} unlocked',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          child: Row(
            children: [
              _catChip(cf, 'All', null),
              _catChip(cf, 'Batting', BadgeType.batting),
              _catChip(cf, 'Bowling', BadgeType.bowling),
              _catChip(cf, 'Fielding', BadgeType.fielding),
              _catChip(cf, 'Captaincy', BadgeType.captaincy),
              _catChip(cf, 'Career', BadgeType.career),
              _catChip(cf, 'Special', BadgeType.special),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: AppDimens.listPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
              mainAxisSpacing: AppDimens.spaceSm,
              crossAxisSpacing: AppDimens.spaceSm,
              childAspectRatio: 0.72,
            ),
            itemCount: page.length + (list.length > _visible ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= page.length) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() => _visible += _pageSize),
                    child: const Text('Load more'),
                  ),
                );
              }
              return _BadgeTile(
                progress: page[i],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BadgeDetailScreen(progress: page[i]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _catChip(CfColors cf, String label, BadgeType? type) {
    final selected = _category == type;
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.spaceXs),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _category = type;
          _visible = _pageSize;
        }),
        selectedColor: cf.accent.withValues(alpha: 0.15),
        checkmarkColor: cf.accent,
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.progress, required this.onTap});

  final PlayerBadgeProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final def = progress.definition;
    final tierColor = switch (def.tier) {
      BadgeTier.bronze => const Color(0xFFCD7F32),
      BadgeTier.silver => const Color(0xFFC0C0C0),
      BadgeTier.gold => const Color(0xFFD4AF37),
      BadgeTier.diamond => const Color(0xFF64B5F6),
    };

    return Opacity(
      opacity: progress.unlocked ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            decoration: cfCardDecoration(context).copyWith(
              border: Border.all(
                color: progress.unlocked
                    ? tierColor.withValues(alpha: 0.5)
                    : cf.border,
              ),
            ),
            padding: const EdgeInsets.all(AppDimens.spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      progress.unlocked ? Icons.verified : Icons.lock_outline,
                      color: tierColor,
                      size: 22,
                    ),
                    const Spacer(),
                    Text(
                      def.tier.name.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: tierColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  def.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  def.requirement,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                        fontSize: 10,
                      ),
                ),
                const Spacer(),
                if (progress.unlocked) ...[
                  if (progress.isRepeatable) ...[
                    Text(
                      'Achieved ${progress.unlockCount} ${progress.unlockCount == 1 ? 'Time' : 'Times'}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cf.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (progress.lastAchievedAt != null)
                      Text(
                        'Last Achieved:\n${DateFormat('d MMM yyyy').format(progress.lastAchievedAt!)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                  ] else ...[
                    Text(
                      'Unlocked',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cf.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (progress.unlockedAt != null)
                      Text(
                        DateFormat('d MMM yyyy').format(progress.unlockedAt!),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                  ],
                ] else ...[
                  LinearProgressIndicator(
                    value: (progress.completionPct / 100).clamp(0, 1),
                    backgroundColor: cf.sectionBackground,
                    color: cf.accent,
                    minHeight: 4,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.nextTierTitle != null
                        ? '${progress.completionPct.toStringAsFixed(0)}% to ${progress.nextTierTitle}'
                        : '${progress.completionPct.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

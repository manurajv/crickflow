import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../domain/services/player_cricket_profile_models.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

class BadgeDetailScreen extends StatelessWidget {
  const BadgeDetailScreen({super.key, required this.progress});

  final PlayerBadgeProgress progress;

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

    return Scaffold(
      appBar: CfChromeAppBar(title: Text(def.title)),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          Row(
            children: [
              Icon(
                progress.unlocked ? Icons.verified : Icons.lock_outline,
                color: tierColor,
                size: 40,
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      def.tier.name.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: tierColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            def.requirement,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          if (progress.unlocked) ...[
            if (progress.isRepeatable) ...[
              Text(
                'Achieved ${progress.unlockCount} ${progress.unlockCount == 1 ? 'Time' : 'Times'}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (progress.lastAchievedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Last achieved: ${DateFormat('d MMM yyyy').format(progress.lastAchievedAt!)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cf.textSecondary,
                        ),
                  ),
                ),
              if (progress.nextTierTitle != null) ...[
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  'Next tier: ${progress.nextTierTitle}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cf.accent,
                      ),
                ),
              ],
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Achievement history',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              if (progress.achievementHistory.isEmpty)
                Text(
                  'No match history recorded.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                )
              else
                ...progress.achievementHistory.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final h = entry.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: cf.accent.withValues(alpha: 0.15),
                      child: Text(
                        '$i',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cf.accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    title: Text(
                      h.matchTitle.isNotEmpty ? h.matchTitle : 'Match $i',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      [
                        h.performanceSnapshot,
                        DateFormat('d MMM yyyy').format(h.achievedAt),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                  );
                }),
            ] else ...[
              Text(
                'Unlocked',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (progress.unlockedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d MMM yyyy').format(progress.unlockedAt!),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cf.textSecondary,
                        ),
                  ),
                ),
              const SizedBox(height: AppDimens.spaceLg),
              if (progress.unlockMatchTitle != null &&
                  progress.unlockMatchTitle!.isNotEmpty) ...[
                Text(
                  'Unlock match',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  progress.unlockMatchTitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppDimens.spaceMd),
              ],
              if (progress.unlockPerformanceSnapshot != null &&
                  progress.unlockPerformanceSnapshot!.isNotEmpty) ...[
                Text(
                  'Performance snapshot',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  progress.unlockPerformanceSnapshot!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ] else ...[
            LinearProgressIndicator(
              value: (progress.completionPct / 100).clamp(0, 1),
              backgroundColor: cf.sectionBackground,
              color: cf.accent,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              '${progress.completionPct.toStringAsFixed(0)}% complete',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (progress.nextTierTitle != null)
              Text(
                'Progress to ${progress.nextTierTitle}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
              ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/team_profile/team_profile_models.dart';
import '../../../../../shared/providers/team_profile_provider.dart';
import '../widgets/team_profile_empty_state.dart';

class TeamTrophiesTab extends ConsumerWidget {
  const TeamTrophiesTab({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(teamProfileSnapshotProvider(teamId));

    return snapAsync.when(
      loading: () => const TeamProfileSkeleton(),
      error: (e, _) => TeamProfileEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load trophies',
        subtitle: '$e',
      ),
      data: (snap) {
        final trophies = snap.trophies;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(teamProfileSnapshotProvider(teamId));
          },
          child: trophies.isEmpty
              ? const TeamProfileEmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'No trophies yet',
                  subtitle:
                      'Tournament titles and special awards will shine here.',
                )
              : GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppDimens.listPadding,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
                    mainAxisSpacing: AppDimens.spaceSm,
                    crossAxisSpacing: AppDimens.spaceSm,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: trophies.length,
                  itemBuilder: (_, i) => _TrophyCard(trophy: trophies[i]),
                ),
        );
      },
    );
  }
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({required this.trophy});

  final TeamTrophy trophy;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    const gold = Color(0xFFD4AF37);
    final dateLabel = trophy.date == null
        ? ''
        : DateFormat.yMMMd().format(trophy.date!);

    return Container(
      decoration: cfCardDecoration(context).copyWith(
        border: Border.all(color: gold.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(trophy.kind.emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            trophy.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            trophy.kind.title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (trophy.season.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              trophy.season,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
          ],
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
            ),
          ],
          if (trophy.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              trophy.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

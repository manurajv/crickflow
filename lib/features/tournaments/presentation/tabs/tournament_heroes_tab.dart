import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/tournament/tournament_hero_ranking_engine.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import '../widgets/shared/tournament_async_tab.dart';
import '../widgets/overview/tournament_overview_widgets.dart';

class TournamentHeroesTab extends ConsumerWidget {
  const TournamentHeroesTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final heroesAsync = ref.watch(tournamentHeroesProvider(tournamentId));

    return TournamentAsyncTab(
      asyncValue: heroesAsync,
      onRefresh: () async {
        ref.invalidate(tournamentBallEventsProvider(tournamentId));
        ref.invalidate(tournamentHeroesProvider(tournamentId));
      },
      emptyIcon: Icons.emoji_events_outlined,
      emptyTitle: 'No heroes yet',
      emptyDescription:
          'Tournament heroes are calculated automatically from live match data.',
      builder: (snapshot) {
        if (!snapshot.hasData) {
          return const TournamentOverviewEmptyInline(
            message: 'Heroes appear once players start scoring runs and wickets.',
          );
        }

        return ListView(
          padding: AppDimens.screenPadding,
          children: [
            for (final award in TournamentHeroAward.values)
              if (snapshot.heroFor(award) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  child: _HeroCard(
                    cf: cf,
                    entry: snapshot.heroFor(award)!,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.cf, required this.entry});

  final CfColors cf;
  final TournamentHeroEntry entry;

  @override
  Widget build(BuildContext context) {
    final isCap = entry.award == TournamentHeroAward.orangeCap ||
        entry.award == TournamentHeroAward.purpleCap;

    return Card(
      color: cf.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCap ? cf.accent.withValues(alpha: 0.4) : cf.border,
        ),
      ),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cf.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCap ? Icons.military_tech : Icons.emoji_events,
                color: cf.accent,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.award.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cf.accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    entry.playerName.isNotEmpty
                        ? entry.playerName
                        : 'Player',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: cf.textPrimary,
                    ),
                  ),
                  if (entry.teamName.isNotEmpty)
                    Text(
                      entry.teamName,
                      style: TextStyle(
                        fontSize: 12,
                        color: cf.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (entry.valueLabel.isNotEmpty)
              Text(
                entry.valueLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cf.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

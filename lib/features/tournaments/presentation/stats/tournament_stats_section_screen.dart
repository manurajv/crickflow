import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/tournament/tournament_analytics_models.dart';
import '../../../../domain/services/tournament/tournament_leaderboard_models.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import 'widgets/stats_dashboard_widgets.dart';
import 'tournament_player_stats_screen.dart';

class TournamentStatsSectionScreen extends ConsumerWidget {
  const TournamentStatsSectionScreen({
    super.key,
    required this.tournamentId,
    required this.sectionId,
    required this.filter,
    required this.initialSnapshot,
  });

  final String tournamentId;
  final TournamentStatsSectionId sectionId;
  final TournamentAnalyticsFilter filter;
  final TournamentAnalyticsSnapshot initialSnapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final params = TournamentAnalyticsParams(
      tournamentId: tournamentId,
      filter: filter,
    );
    final async = ref.watch(tournamentAnalyticsProvider(params));
    final snapshot = async.valueOrNull ?? initialSnapshot;
    final section = snapshot.sections[sectionId] ??
        TournamentSectionSnapshot(id: sectionId);

    TournamentLeaderboardCategory? sortCategory = section.primaryCategory;

    return Scaffold(
      appBar: AppBar(
        title: Text(sectionId.title),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tournamentBallEventsProvider(tournamentId));
          ref.invalidate(tournamentAnalyticsProvider(params));
        },
        child: ListView(
          padding: AppDimens.screenPadding,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (section.metrics.isNotEmpty) ...[
              Text(
                'Overview',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              StatsMetricGrid(metrics: section.metrics),
              const SizedBox(height: AppDimens.spaceLg),
            ],
            if (section.primaryCategory != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      section.primaryCategory!.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  PopupMenuButton<TournamentLeaderboardCategory>(
                    icon: Icon(Icons.sort, color: cf.textSecondary),
                    initialValue: sortCategory,
                    onSelected: (_) {},
                    itemBuilder: (_) => [
                      for (final c in _categoriesForSection(sectionId))
                        PopupMenuItem(value: c, child: Text(c.title)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              StatsLeaderboardPreview(
                entries: snapshot.entriesFor(section.primaryCategory!, limit: 50),
                onPlayerTap: (e) {
                  final playerId = e.playerId;
                  if (playerId == null || playerId.isEmpty) return;
                  final detail = snapshot.playerDetail(playerId);
                  if (detail == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TournamentPlayerStatsScreen(
                        tournamentId: tournamentId,
                        detail: detail,
                      ),
                    ),
                  );
                },
              ),
            ],
            if (section.chartPreview != null) ...[
              const SizedBox(height: AppDimens.spaceLg),
              StatsMiniChart(series: section.chartPreview!),
            ],
            for (final chart in snapshot.charts
                .where((c) => sectionId == TournamentStatsSectionId.charts))
              Padding(
                padding: const EdgeInsets.only(top: AppDimens.spaceMd),
                child: StatsMiniChart(series: chart),
              ),
          ],
        ),
      ),
    );
  }

  List<TournamentLeaderboardCategory> _categoriesForSection(
    TournamentStatsSectionId id,
  ) =>
      switch (id) {
        TournamentStatsSectionId.batting => kTournamentBattingCategories,
        TournamentStatsSectionId.bowling => kTournamentBowlingCategories,
        TournamentStatsSectionId.fielding => kTournamentFieldingCategories,
        TournamentStatsSectionId.team => kTournamentTeamCategories,
        _ => const [],
      };
}

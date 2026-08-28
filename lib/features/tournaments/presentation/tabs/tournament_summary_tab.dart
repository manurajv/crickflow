import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../domain/services/tournament/tournament_analytics_models.dart';
import '../../../../domain/services/tournament/tournament_hero_ranking_engine.dart';
import '../../../../domain/services/tournament/tournament_leaderboard_models.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import '../../../../shared/widgets/match_team_avatar.dart';
import '../utils/tournament_display_utils.dart';
import '../widgets/overview/tournament_overview_widgets.dart';
import '../widgets/shared/tournament_async_tab.dart';
import '../widgets/tournament_module_empty_state.dart';

/// Completed-tournament report using the same card language as Overview.
class TournamentSummaryTab extends ConsumerWidget {
  const TournamentSummaryTab({
    super.key,
    required this.tournamentId,
    required this.tournament,
  });

  final String tournamentId;
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tournament.status != TournamentStatus.completed) {
      return const TournamentModuleEmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'Summary unlocks after the final',
        description:
            'Finish the tournament from Settings to lock the result and see champions, awards, and records.',
      );
    }

    final teams = ref.watch(allTeamsProvider).valueOrNull ?? const <TeamModel>[];
    final analyticsAsync = ref.watch(
      tournamentAnalyticsProvider(
        TournamentAnalyticsParams(tournamentId: tournamentId),
      ),
    );

    return TournamentAsyncTab<TournamentAnalyticsSnapshot>(
      asyncValue: analyticsAsync,
      onRefresh: () async {
        ref.invalidate(tournamentBallEventsProvider(tournamentId));
        ref.invalidate(
          tournamentAnalyticsProvider(
            TournamentAnalyticsParams(tournamentId: tournamentId),
          ),
        );
      },
      emptyIcon: Icons.emoji_events_outlined,
      emptyTitle: 'Summary unavailable',
      emptyDescription:
          'Tournament summary will be generated once match data is available.',
      builder: (snapshot) {
        return ListView(
          padding: AppDimens.screenPadding,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _SummaryHeader(tournament: tournament),
            _ChampionsSection(tournament: tournament, teams: teams),
            if (snapshot.hasData) ...[
              _TournamentAwardsSection(awards: snapshot.awards),
              _LeaderboardSection(
                title: 'Batting leaders',
                categories: kTournamentBattingCategories,
                snapshot: snapshot,
              ),
              _LeaderboardSection(
                title: 'Bowling leaders',
                categories: kTournamentBowlingCategories,
                snapshot: snapshot,
              ),
              _LeaderboardSection(
                title: 'Fielding leaders',
                categories: kTournamentFieldingCategories,
                snapshot: snapshot,
              ),
              _TeamStatisticsSection(snapshot: snapshot),
              _TournamentRecordsSection(snapshot: snapshot),
              _TournamentNumbersSection(snapshot: snapshot),
            ] else
              const TournamentOverviewSectionCard(
                title: 'Match data',
                child: TournamentOverviewEmptyInline(
                  message:
                      'No scored matches yet. Summary stats appear once innings are recorded.',
                  icon: Icons.sports_cricket_outlined,
                ),
              ),
            _TournamentTimelineSection(tournament: tournament),
            const SizedBox(height: AppDimens.spaceLg),
          ],
        );
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final champion = tournament.championTeamName?.trim();
    final details = <String>[
      tournamentFormatLabel(tournament.format),
      if (tournament.teamIds.isNotEmpty)
        '${tournament.teamIds.length} teams',
      if (tournament.matchIds.isNotEmpty)
        '${tournament.matchIds.length} matches',
      if (tournament.defaultRules.totalOvers > 0)
        '${tournament.defaultRules.totalOvers} overs',
    ];

    return TournamentOverviewSectionCard(
      title: 'Result',
      trailing: const TournamentStatusChip(status: TournamentStatus.completed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (tournament.logoUrl != null && tournament.logoUrl!.isNotEmpty)
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      CachedNetworkImageProvider(tournament.logoUrl!),
                )
              else
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cf.accent.withValues(alpha: 0.12),
                  child: Icon(Icons.emoji_events_outlined, color: cf.accent),
                ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Text(
                  tournament.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cf.textPrimary,
                      ),
                ),
              ),
            ],
          ),
          if (champion != null && champion.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Container(
              width: double.infinity,
              padding: AppDimens.cardPadding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cf.accent.withValues(alpha: 0.18),
                    cf.accent.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cf.accent.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: cf.accent, size: 22),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Champion',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cf.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          champion,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cf.textPrimary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceSm,
              children: [
                for (final label in details) _MetaChip(label: label),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cf.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cf.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ChampionsSection extends StatelessWidget {
  const _ChampionsSection({
    required this.tournament,
    required this.teams,
  });

  final TournamentModel tournament;
  final List<TeamModel> teams;

  @override
  Widget build(BuildContext context) {
    final podium = tournament.effectivePodiumPlaces;
    if (podium.isEmpty) return const SizedBox.shrink();

    TeamModel? teamFor(String id) {
      for (final team in teams) {
        if (team.id == id) return team;
      }
      return null;
    }

    return TournamentOverviewSectionCard(
      title: 'Podium',
      child: Column(
        children: [
          for (var i = 0; i < podium.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.spaceSm),
            _PodiumRow(
              place: podium[i],
              team: teamFor(podium[i].teamId),
              highlight: podium[i].place == 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _PodiumRow extends StatelessWidget {
  const _PodiumRow({
    required this.place,
    required this.team,
    required this.highlight,
  });

  final TournamentPodiumPlace place;
  final TeamModel? team;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final name = place.teamName.isNotEmpty
        ? place.teamName
        : (team?.name ?? place.teamId);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? cf.accent.withValues(alpha: 0.08)
            : cf.sectionBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? cf.accent.withValues(alpha: 0.28) : cf.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${place.place}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: highlight ? cf.accent : cf.textMuted,
                  ),
            ),
          ),
          MatchTeamAvatar(
            name: name,
            logoUrl: team?.profileImageUrl,
            size: 36,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TournamentPodiumPlace.labelFor(place.place),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cf.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentAwardsSection extends StatelessWidget {
  const _TournamentAwardsSection({required this.awards});

  final TournamentHeroesSnapshot awards;

  @override
  Widget build(BuildContext context) {
    if (!awards.hasData) return const SizedBox.shrink();

    return TournamentOverviewSectionCard(
      title: 'Awards',
      child: Column(
        children: [
          for (var i = 0; i < awards.heroes.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.spaceSm),
            _AwardRow(entry: awards.heroes[i]),
          ],
        ],
      ),
    );
  }
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.entry});

  final TournamentHeroEntry entry;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cf.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.emoji_events_outlined, color: cf.accent, size: 20),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.award.title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cf.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                entry.playerName.isNotEmpty ? entry.playerName : 'Player',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cf.textPrimary,
                    ),
              ),
              if (entry.teamName.isNotEmpty)
                Text(
                  entry.teamName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
            ],
          ),
        ),
        if (entry.valueLabel.isNotEmpty)
          Text(
            entry.valueLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cf.accent,
                ),
          ),
      ],
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({
    required this.title,
    required this.categories,
    required this.snapshot,
  });

  final String title;
  final List<TournamentLeaderboardCategory> categories;
  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final populated = categories
        .where((c) => snapshot.entriesFor(c, limit: 5).isNotEmpty)
        .toList();
    if (populated.isEmpty) return const SizedBox.shrink();

    return TournamentOverviewSectionCard(
      title: title,
      child: Column(
        children: [
          for (var i = 0; i < populated.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.spaceMd),
            _LeaderboardCategoryBlock(
              category: populated[i],
              entries: snapshot.entriesFor(populated[i], limit: 5),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardCategoryBlock extends StatelessWidget {
  const _LeaderboardCategoryBlock({
    required this.category,
    required this.entries,
  });

  final TournamentLeaderboardCategory category;
  final List<TournamentLeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cf.accent,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        for (final entry in entries) _LeaderboardRow(entry: entry),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final TournamentLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final first = entry.rank == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${entry.rank}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: first ? cf.accent : cf.textMuted,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: first ? FontWeight.w700 : FontWeight.w500,
                        color: cf.textPrimary,
                      ),
                ),
                if (entry.teamName.isNotEmpty)
                  Text(
                    entry.teamName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cf.textMuted,
                        ),
                  ),
              ],
            ),
          ),
          Text(
            entry.valueLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: first ? cf.accent : cf.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _TeamStatisticsSection extends StatelessWidget {
  const _TeamStatisticsSection({required this.snapshot});

  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = <StatsMetric>[
      ...?snapshot.sections[TournamentStatsSectionId.team]?.metrics,
      ...?snapshot.sections[TournamentStatsSectionId.matchSummary]?.metrics,
    ].where(_hasMetricValue).toList();
    if (metrics.isEmpty) return const SizedBox.shrink();

    return TournamentOverviewSectionCard(
      title: 'Team statistics',
      child: TournamentOverviewStatGrid(
        stats: [
          for (final metric in metrics.take(6))
            TournamentOverviewStatItem(
              label: metric.label,
              value: metric.value,
              icon: Icons.groups_outlined,
            ),
        ],
      ),
    );
  }
}

class _TournamentRecordsSection extends StatelessWidget {
  const _TournamentRecordsSection({required this.snapshot});

  final TournamentAnalyticsSnapshot snapshot;

  static const _labels = {
    'Highest individual score',
    'Best bowling',
    'Longest partnership',
    'Highest team score',
    'Lowest team score',
    'Highest chase',
    'Biggest win',
    'Closest match',
    'Most extras in a match',
    'Most sixes in a match',
  };

  @override
  Widget build(BuildContext context) {
    final records = snapshot.summary.metrics
        .where((m) => _labels.contains(m.label) && _hasMetricValue(m))
        .toList();
    if (records.isEmpty) return const SizedBox.shrink();

    return TournamentOverviewSectionCard(
      title: 'Records',
      child: Column(
        children: [
          for (final record in records)
            TournamentOverviewDetailRow(
              label: record.label,
              value: record.subtitle == null || record.subtitle!.isEmpty
                  ? record.value
                  : '${record.value} · ${record.subtitle}',
            ),
        ],
      ),
    );
  }
}

class _TournamentNumbersSection extends StatelessWidget {
  const _TournamentNumbersSection({required this.snapshot});

  final TournamentAnalyticsSnapshot snapshot;

  static const _labels = {
    'Matches',
    'Completed',
    'Overs bowled',
    'Runs scored',
    'Balls bowled',
    'Boundaries',
    'Sixes',
    'Fours',
    'Extras',
    'Wickets fallen',
    'Batting average',
    'Run rate',
  };

  @override
  Widget build(BuildContext context) {
    final numbers = snapshot.summary.metrics
        .where((m) => _labels.contains(m.label) && _hasMetricValue(m))
        .toList();
    if (numbers.isEmpty) return const SizedBox.shrink();

    return TournamentOverviewSectionCard(
      title: 'Tournament numbers',
      child: TournamentOverviewStatGrid(
        stats: [
          for (final metric in numbers.take(8))
            TournamentOverviewStatItem(
              label: metric.label,
              value: metric.value,
              icon: Icons.bar_chart_outlined,
            ),
        ],
      ),
    );
  }
}

class _TournamentTimelineSection extends StatelessWidget {
  const _TournamentTimelineSection({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final events = <({String label, String value})>[];
    if (tournament.startDate != null) {
      events.add((
        label: 'Started',
        value: AppDateUtils.formatCardDate(tournament.startDate!),
      ));
    }
    if (tournament.endDate != null) {
      events.add((
        label: 'Completed',
        value: AppDateUtils.formatCardDate(tournament.endDate!),
      ));
    }
    final champion = tournament.championTeamName?.trim();
    if (champion != null && champion.isNotEmpty) {
      events.add((label: 'Champion', value: champion));
    }
    if (events.isEmpty) return const SizedBox.shrink();

    return TournamentOverviewSectionCard(
      title: 'Timeline',
      child: Column(
        children: [
          for (final event in events)
            TournamentOverviewDetailRow(
              label: event.label,
              value: event.value,
            ),
        ],
      ),
    );
  }
}

bool _hasMetricValue(StatsMetric metric) =>
    metric.value.isNotEmpty && metric.value != '—' && metric.value != '0';

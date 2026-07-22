import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../domain/services/tournament/tournament_analytics_models.dart';
import '../../../../domain/services/tournament/tournament_hero_ranking_engine.dart';
import '../../../../domain/services/tournament/tournament_leaderboard_models.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import '../widgets/shared/tournament_async_tab.dart';

/// Premium tournament summary — only shown for completed tournaments.
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
      emptyIcon: Icons.emoji_events,
      emptyTitle: 'Summary unavailable',
      emptyDescription:
          'Tournament summary will be generated once match data is available.',
      builder: (snapshot) {
        if (!snapshot.hasData) {
          return ListView(
            padding: AppDimens.screenPadding,
            children: const [
              SizedBox(height: 100),
              Center(
                child: Text('No scored matches to build summary from.'),
              ),
            ],
          );
        }
        return ListView(
          padding: AppDimens.screenPadding,
          children: [
            _SummaryHeader(tournament: tournament),
            const SizedBox(height: AppDimens.spaceLg),
            _ChampionsSection(tournament: tournament),
            const SizedBox(height: AppDimens.spaceLg),
            _TournamentAwardsSection(awards: snapshot.awards),
            const SizedBox(height: AppDimens.spaceLg),
            _BattingLeadersSection(snapshot: snapshot),
            const SizedBox(height: AppDimens.spaceLg),
            _BowlingLeadersSection(snapshot: snapshot),
            const SizedBox(height: AppDimens.spaceLg),
            _FieldingLeadersSection(snapshot: snapshot),
            const SizedBox(height: AppDimens.spaceLg),
            _TeamStatisticsSection(snapshot: snapshot),
            const SizedBox(height: AppDimens.spaceLg),
            _TournamentRecordsSection(snapshot: snapshot),
            const SizedBox(height: AppDimens.spaceLg),
            _TournamentNumbersSection(snapshot: snapshot),
            const SizedBox(height: AppDimens.spaceLg),
            _TournamentTimelineSection(tournament: tournament),
            const SizedBox(height: AppDimens.spaceXl),
          ],
        );
      },
    );
  }
}


// ─── Header ─────────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.tournament});
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      decoration: BoxDecoration(
        gradient: cf.heroGradient,
        borderRadius: AppDimens.cardRadius,
        border: Border.all(color: cf.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (tournament.logoUrl != null)
            CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(tournament.logoUrl!),
            )
          else
            CircleAvatar(
              radius: 32,
              backgroundColor: cf.accent.withValues(alpha: 0.2),
              child: Icon(Icons.emoji_events, color: cf.accent, size: 32),
            ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            tournament.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cf.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          if (tournament.championTeamName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: CfColors.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '🏆 ${tournament.championTeamName}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cf.onAccent,
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(height: AppDimens.spaceMd),
          Wrap(
            spacing: AppDimens.spaceMd,
            runSpacing: AppDimens.spaceSm,
            alignment: WrapAlignment.center,
            children: [
              _HeaderChip(label: tournament.format.name.toUpperCase(), cf: cf),
              _HeaderChip(
                label: '${tournament.teamIds.length} Teams',
                cf: cf,
              ),
              _HeaderChip(
                label: '${tournament.matchIds.length} Matches',
                cf: cf,
              ),
              if (tournament.defaultRules.totalOvers > 0)
                _HeaderChip(
                  label: '${tournament.defaultRules.totalOvers} Overs',
                  cf: cf,
                ),
              if (tournament.grounds.isNotEmpty)
                _HeaderChip(
                  label: tournament.grounds.length == 1
                      ? tournament.grounds.first
                      : '${tournament.grounds.length} Venues',
                  cf: cf,
                ),
              if (tournament.startDate != null && tournament.endDate != null)
                _HeaderChip(
                  label: _durationLabel(
                    tournament.startDate!,
                    tournament.endDate!,
                  ),
                  cf: cf,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _durationLabel(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    if (days <= 1) return '1 Day';
    return '$days Days';
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.cf});
  final String label;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cf.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cf.textSecondary,
        ),
      ),
    );
  }
}

// ─── Champions ──────────────────────────────────────────────────────────────

class _ChampionsSection extends StatelessWidget {
  const _ChampionsSection({required this.tournament});
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final podium = tournament.effectivePodiumPlaces;
    if (podium.isEmpty) return const SizedBox.shrink();

    return _SummarySection(
      title: 'Champions',
      icon: Icons.military_tech,
      child: Column(
        children: [
          for (var i = 0; i < podium.length; i++) ...[
            if (i > 0) const SizedBox(height: AppDimens.spaceSm),
            _PodiumCard(
              cf: cf,
              rank: TournamentPodiumPlace.emojiFor(podium[i].place),
              label: TournamentPodiumPlace.labelFor(podium[i].place),
              teamName: podium[i].teamName.isNotEmpty
                  ? podium[i].teamName
                  : podium[i].teamId,
              gradient: podium[i].place == 1 ? CfColors.goldGradient : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.cf,
    required this.rank,
    required this.label,
    required this.teamName,
    this.gradient,
  });

  final CfColors cf;
  final String rank;
  final String label;
  final String teamName;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppDimens.cardPadding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? cf.card : null,
        borderRadius: AppDimens.cardRadius,
        border: Border.all(
          color: gradient != null
              ? CfColors.gold.withValues(alpha: 0.5)
              : cf.border,
        ),
      ),
      child: Row(
        children: [
          Text(rank, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: gradient != null ? cf.onAccent : cf.textMuted,
                  ),
                ),
                Text(
                  teamName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: gradient != null ? cf.onAccent : cf.textPrimary,
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

// ─── Awards ─────────────────────────────────────────────────────────────────

class _TournamentAwardsSection extends StatelessWidget {
  const _TournamentAwardsSection({required this.awards});
  final TournamentHeroesSnapshot awards;

  @override
  Widget build(BuildContext context) {
    if (!awards.hasData) return const SizedBox.shrink();
    final cf = context.cf;

    return _SummarySection(
      title: 'Tournament Awards',
      icon: Icons.emoji_events,
      child: Column(
        children: [
          for (final entry in awards.heroes) ...[
            _AwardCard(entry: entry, cf: cf),
            const SizedBox(height: AppDimens.spaceSm),
          ],
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.entry, required this.cf});
  final TournamentHeroEntry entry;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppDimens.cardPadding,
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: AppDimens.cardRadius,
        border: Border.all(color: cf.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cf.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.emoji_events, color: cf.accent, size: 22),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.award.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cf.accent,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  entry.playerName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cf.textPrimary,
                  ),
                ),
                if (entry.teamName.isNotEmpty)
                  Text(
                    entry.teamName,
                    style: TextStyle(fontSize: 11, color: cf.textSecondary),
                  ),
              ],
            ),
          ),
          if (entry.valueLabel.isNotEmpty)
            Text(
              entry.valueLabel,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: cf.accent,
              ),
            ),
        ],
      ),
    );
  }
}


// ─── Batting Leaders ────────────────────────────────────────────────────────

class _BattingLeadersSection extends StatelessWidget {
  const _BattingLeadersSection({required this.snapshot});
  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _LeaderboardSection(
      title: 'Batting Leaders',
      icon: Icons.sports_baseball,
      categories: kTournamentBattingCategories,
      snapshot: snapshot,
    );
  }
}

// ─── Bowling Leaders ────────────────────────────────────────────────────────

class _BowlingLeadersSection extends StatelessWidget {
  const _BowlingLeadersSection({required this.snapshot});
  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _LeaderboardSection(
      title: 'Bowling Leaders',
      icon: Icons.track_changes,
      categories: kTournamentBowlingCategories,
      snapshot: snapshot,
    );
  }
}

// ─── Fielding Leaders ───────────────────────────────────────────────────────

class _FieldingLeadersSection extends StatelessWidget {
  const _FieldingLeadersSection({required this.snapshot});
  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _LeaderboardSection(
      title: 'Fielding Leaders',
      icon: Icons.front_hand,
      categories: kTournamentFieldingCategories,
      snapshot: snapshot,
    );
  }
}

class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({
    required this.title,
    required this.icon,
    required this.categories,
    required this.snapshot,
  });

  final String title;
  final IconData icon;
  final List<TournamentLeaderboardCategory> categories;
  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    // Only show categories that have data.
    final populated = categories
        .where((c) => snapshot.entriesFor(c, limit: 10).isNotEmpty)
        .toList();
    if (populated.isEmpty) return const SizedBox.shrink();

    return _SummarySection(
      title: title,
      icon: icon,
      child: Column(
        children: [
          for (final category in populated) ...[
            _LeaderboardCategoryCard(
              category: category,
              entries: snapshot.entriesFor(category, limit: 10),
              cf: cf,
            ),
            const SizedBox(height: AppDimens.spaceSm),
          ],
        ],
      ),
    );
  }
}

class _LeaderboardCategoryCard extends StatelessWidget {
  const _LeaderboardCategoryCard({
    required this.category,
    required this.entries,
    required this.cf,
  });

  final TournamentLeaderboardCategory category;
  final List<TournamentLeaderboardEntry> entries;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: AppDimens.cardRadius,
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              category.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cf.accent,
              ),
            ),
          ),
          for (int i = 0; i < entries.length; i++)
            _LeaderboardRow(
              entry: entries[i],
              cf: cf,
              isFirst: i == 0,
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.cf,
    this.isFirst = false,
  });

  final TournamentLeaderboardEntry entry;
  final CfColors cf;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isFirst ? cf.accent : cf.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isFirst ? FontWeight.w700 : FontWeight.w500,
                    color: cf.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.teamName.isNotEmpty)
                  Text(
                    entry.teamName,
                    style: TextStyle(fontSize: 10, color: cf.textMuted),
                  ),
              ],
            ),
          ),
          Text(
            entry.valueLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isFirst ? cf.accent : cf.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Team Statistics ────────────────────────────────────────────────────────

class _TeamStatisticsSection extends StatelessWidget {
  const _TeamStatisticsSection({required this.snapshot});
  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final section =
        snapshot.sections[TournamentStatsSectionId.team];
    final matchSection =
        snapshot.sections[TournamentStatsSectionId.matchSummary];
    final metrics = <StatsMetric>[
      ...?section?.metrics,
      ...?matchSection?.metrics,
    ];
    if (metrics.isEmpty) return const SizedBox.shrink();

    return _SummarySection(
      title: 'Team Statistics',
      icon: Icons.groups,
      child: _MetricGrid(metrics: metrics, cf: cf),
    );
  }
}

// ─── Tournament Records ─────────────────────────────────────────────────────

class _TournamentRecordsSection extends StatelessWidget {
  const _TournamentRecordsSection({required this.snapshot});
  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final summary = snapshot.summary.metrics;
    // Pick record-oriented metrics.
    final recordLabels = {
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
    final records =
        summary.where((m) => recordLabels.contains(m.label)).toList();
    if (records.isEmpty) return const SizedBox.shrink();

    return _SummarySection(
      title: 'Tournament Records',
      icon: Icons.star,
      child: _MetricGrid(metrics: records, cf: cf),
    );
  }
}

// ─── Tournament Numbers ─────────────────────────────────────────────────────

class _TournamentNumbersSection extends StatelessWidget {
  const _TournamentNumbersSection({required this.snapshot});
  final TournamentAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final summary = snapshot.summary.metrics;
    final numberLabels = {
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
    final numbers =
        summary.where((m) => numberLabels.contains(m.label)).toList();
    if (numbers.isEmpty) return const SizedBox.shrink();

    return _SummarySection(
      title: 'Tournament Numbers',
      icon: Icons.bar_chart,
      child: _MetricGrid(metrics: numbers, cf: cf),
    );
  }
}

// ─── Timeline ───────────────────────────────────────────────────────────────

class _TournamentTimelineSection extends StatelessWidget {
  const _TournamentTimelineSection({required this.tournament});
  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final events = <_TimelineEvent>[];

    if (tournament.startDate != null) {
      events.add(_TimelineEvent(
        label: 'Tournament Started',
        date: _formatDate(tournament.startDate!),
        icon: Icons.flag,
      ));
    }
    if (tournament.endDate != null) {
      events.add(_TimelineEvent(
        label: 'Tournament Completed',
        date: _formatDate(tournament.endDate!),
        icon: Icons.emoji_events,
      ));
    }
    if (tournament.championTeamName != null) {
      events.add(_TimelineEvent(
        label: 'Champion Crowned',
        date: tournament.championTeamName!,
        icon: Icons.military_tech,
      ));
    }

    if (events.isEmpty) return const SizedBox.shrink();

    return _SummarySection(
      title: 'Tournament Timeline',
      icon: Icons.timeline,
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++)
            _TimelineTile(
              event: events[i],
              cf: cf,
              isLast: i == events.length - 1,
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _TimelineEvent {
  const _TimelineEvent({
    required this.label,
    required this.date,
    required this.icon,
  });
  final String label;
  final String date;
  final IconData icon;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    required this.cf,
    this.isLast = false,
  });

  final _TimelineEvent event;
  final CfColors cf;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: cf.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, size: 14, color: cf.accent),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: cf.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: cf.textPrimary,
                    ),
                  ),
                  Text(
                    event.date,
                    style: TextStyle(
                      fontSize: 12,
                      color: cf.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ─────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cf.accent),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: cf.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        child,
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.cf});
  final List<StatsMetric> metrics;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.spaceSm,
      runSpacing: AppDimens.spaceSm,
      children: [
        for (final m in metrics)
          if (m.value != '—' && m.value != '0')
            _MetricTile(metric: m, cf: cf),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.cf});
  final StatsMetric metric;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 36) / 2,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cf.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: cf.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (metric.subtitle != null)
            Text(
              metric.subtitle!,
              style: TextStyle(fontSize: 9, color: cf.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

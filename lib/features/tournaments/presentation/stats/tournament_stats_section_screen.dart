import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/tournament/tournament_analytics_models.dart';
import '../../../../domain/services/tournament/tournament_leaderboard_models.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import 'widgets/stats_dashboard_widgets.dart';
import 'tournament_player_stats_screen.dart';

class TournamentStatsSectionScreen extends ConsumerStatefulWidget {
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
  ConsumerState<TournamentStatsSectionScreen> createState() =>
      _TournamentStatsSectionScreenState();
}

class _TournamentStatsSectionScreenState
    extends ConsumerState<TournamentStatsSectionScreen> {
  TournamentLeaderboardCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory =
        widget.initialSnapshot.sections[widget.sectionId]?.primaryCategory;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final params = TournamentAnalyticsParams(
      tournamentId: widget.tournamentId,
      filter: widget.filter,
    );
    final async = ref.watch(tournamentAnalyticsProvider(params));
    final snapshot = async.valueOrNull ?? widget.initialSnapshot;
    final section = snapshot.sections[widget.sectionId] ??
        TournamentSectionSnapshot(id: widget.sectionId);
    final categories = _categoriesForSection(widget.sectionId);
    final activeCategory = _selectedCategory ?? section.primaryCategory;
    final chartSeries =
        snapshot.charts.where((c) => c.points.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sectionId.title),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tournamentBallEventsProvider(widget.tournamentId));
          ref.invalidate(tournamentAnalyticsProvider(params));
        },
        child: !section.hasContent
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppDimens.screenPadding,
                children: [
                  Text(
                    'No data for this scope yet.',
                    style: TextStyle(color: cf.textMuted),
                  ),
                ],
              )
            : ListView(
                padding: AppDimens.screenPadding,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (widget.filter.scopeLabel.isNotEmpty &&
                      widget.filter.scope != TournamentAnalyticsScope.tournament)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                      child: _ScopeBadge(
                        label: widget.filter.scopeLabel,
                        cf: cf,
                      ),
                    ),
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
                  if (widget.sectionId == TournamentStatsSectionId.partnerships &&
                      section.partnershipPreview.isNotEmpty) ...[
                    Text(
                      'All partnerships',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    StatsPartnershipPreview(entries: section.partnershipPreview),
                    const SizedBox(height: AppDimens.spaceLg),
                  ],
                  if (widget.sectionId == TournamentStatsSectionId.toss &&
                      section.tossInsights != null) ...[
                    Text(
                      'Breakdown',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    StatsTossBreakdown(insights: section.tossInsights!),
                    const SizedBox(height: AppDimens.spaceLg),
                  ],
                  if (activeCategory != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activeCategory.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        if (categories.length > 1)
                          PopupMenuButton<TournamentLeaderboardCategory>(
                            tooltip: 'Sort by',
                            icon: Icon(Icons.sort, color: cf.textSecondary),
                            initialValue: activeCategory,
                            onSelected: (category) {
                              setState(() => _selectedCategory = category);
                            },
                            itemBuilder: (_) => [
                              for (final c in categories)
                                PopupMenuItem(
                                  value: c,
                                  child: Text(c.title),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    StatsLeaderboardPreview(
                      entries: snapshot.entriesFor(activeCategory, limit: 50),
                      onPlayerTap: _isPlayerCategory(activeCategory)
                          ? (e) {
                              final playerId = e.playerId;
                              if (playerId == null || playerId.isEmpty) return;
                              final detail = snapshot.playerDetail(playerId);
                              if (detail == null) return;
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TournamentPlayerStatsScreen(
                                    tournamentId: widget.tournamentId,
                                    detail: detail,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ],
                  if (widget.sectionId == TournamentStatsSectionId.charts &&
                      chartSeries.isNotEmpty) ...[
                    Text(
                      'All charts',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    for (final chart in chartSeries)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDimens.spaceMd,
                        ),
                        child: StatsMiniChart(series: chart),
                      ),
                  ] else if (section.chartPreview != null &&
                      widget.sectionId != TournamentStatsSectionId.charts) ...[
                    const SizedBox(height: AppDimens.spaceLg),
                    StatsMiniChart(series: section.chartPreview!),
                  ],
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

  bool _isPlayerCategory(TournamentLeaderboardCategory? category) {
    if (category == null) return false;
    return !kTournamentTeamCategories.contains(category);
  }
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.label, required this.cf});

  final String label;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cf.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cf.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list, size: 14, color: cf.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cf.accent,
            ),
          ),
        ],
      ),
    );
  }
}

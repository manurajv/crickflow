import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament/tournament_group_model.dart';
import '../../../../data/models/tournament/tournament_round_model.dart';
import '../../../../domain/services/tournament/tournament_leaderboard_models.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../widgets/shared/tournament_async_tab.dart';
import '../widgets/overview/tournament_overview_widgets.dart';

class TournamentLeaderboardTab extends ConsumerStatefulWidget {
  const TournamentLeaderboardTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<TournamentLeaderboardTab> createState() =>
      _TournamentLeaderboardTabState();
}

class _TournamentLeaderboardTabState
    extends ConsumerState<TournamentLeaderboardTab> {
  TournamentLeaderboardCategory _category =
      TournamentLeaderboardCategory.mostRuns;
  String? _groupId;
  String? _roundId;

  TournamentLeaderboardParams get _params => TournamentLeaderboardParams(
        tournamentId: widget.tournamentId,
        groupId: _groupId,
        roundId: _roundId,
        scopeLabel: _scopeLabel(),
      );

  String _scopeLabel() {
    if (_groupId != null) {
      final groups =
          ref.read(tournamentGroupsProvider(widget.tournamentId)).valueOrNull ??
              [];
      return groups.where((g) => g.id == _groupId).firstOrNull?.name ?? 'Group';
    }
    if (_roundId != null) {
      final rounds =
          ref.read(tournamentRoundsProvider(widget.tournamentId)).valueOrNull ??
              [];
      return rounds.where((r) => r.id == _roundId).firstOrNull?.name ?? 'Round';
    }
    return 'Tournament';
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final groupsAsync = ref.watch(tournamentGroupsProvider(widget.tournamentId));
    final roundsAsync = ref.watch(tournamentRoundsProvider(widget.tournamentId));
    final boardAsync = ref.watch(tournamentLeaderboardProvider(_params));

    return TournamentAsyncTab(
      asyncValue: boardAsync,
      onRefresh: () async {
        ref.invalidate(tournamentBallEventsProvider(widget.tournamentId));
        ref.invalidate(tournamentLeaderboardProvider(_params));
      },
      emptyIcon: Icons.leaderboard_outlined,
      emptyTitle: 'No leaderboard data yet',
      emptyDescription:
          'Leaderboard rankings appear once tournament matches are scored.',
      builder: (snapshot) {
        if (!snapshot.hasData) {
          return const TournamentOverviewEmptyInline(
            message: 'Score a match to populate the leaderboard.',
          );
        }

        return ListView(
          padding: AppDimens.screenPadding,
          children: [
            _ScopeFilters(
              cf: cf,
              groups: groupsAsync.valueOrNull ?? [],
              rounds: roundsAsync.valueOrNull ?? [],
              groupId: _groupId,
              roundId: _roundId,
              onGroupChanged: (v) => setState(() {
                _groupId = v;
                _roundId = null;
              }),
              onRoundChanged: (v) => setState(() {
                _roundId = v;
                _groupId = null;
              }),
              onClear: () => setState(() {
                _groupId = null;
                _roundId = null;
              }),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            _CategoryChips(
              category: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TournamentOverviewSectionCard(
              title: _category.title,
              trailing: Text(
                snapshot.scopeLabel,
                style: TextStyle(color: cf.textSecondary, fontSize: 12),
              ),
              child: _LeaderboardList(
                entries: snapshot.entriesFor(_category),
                cf: cf,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ..._buildSectionPreviews(snapshot, cf),
          ],
        );
      },
    );
  }

  List<Widget> _buildSectionPreviews(
    TournamentLeaderboardSnapshot snapshot,
    CfColors cf,
  ) {
    final sections = switch (_category) {
      TournamentLeaderboardCategory.mostRuns ||
      TournamentLeaderboardCategory.highestScore ||
      TournamentLeaderboardCategory.mostFours ||
      TournamentLeaderboardCategory.mostSixes ||
      TournamentLeaderboardCategory.bestStrikeRate ||
      TournamentLeaderboardCategory.mostFifties ||
      TournamentLeaderboardCategory.mostHundreds =>
        kTournamentBattingCategories,
      TournamentLeaderboardCategory.mostWickets ||
      TournamentLeaderboardCategory.bestBowlingFigures ||
      TournamentLeaderboardCategory.bestEconomy ||
      TournamentLeaderboardCategory.bestBowlingStrikeRate ||
      TournamentLeaderboardCategory.mostMaidens =>
        kTournamentBowlingCategories,
      TournamentLeaderboardCategory.mostCatches ||
      TournamentLeaderboardCategory.mostRunOuts ||
      TournamentLeaderboardCategory.mostStumpings =>
        kTournamentFieldingCategories,
      _ => kTournamentTeamCategories,
    };

    return sections
        .where((c) => c != _category && snapshot.entriesFor(c).isNotEmpty)
        .take(2)
        .map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
            child: TournamentOverviewSectionCard(
              title: c.title,
              child: _LeaderboardList(
                entries: snapshot.entriesFor(c).take(3).toList(),
                cf: cf,
                compact: true,
              ),
            ),
          ),
        )
        .toList();
  }
}

class _ScopeFilters extends StatelessWidget {
  const _ScopeFilters({
    required this.cf,
    required this.groups,
    required this.rounds,
    required this.groupId,
    required this.roundId,
    required this.onGroupChanged,
    required this.onRoundChanged,
    required this.onClear,
  });

  final CfColors cf;
  final List<TournamentGroupModel> groups;
  final List<TournamentRoundModel> rounds;
  final String? groupId;
  final String? roundId;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String?> onRoundChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty && rounds.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: groupId == null && roundId == null,
          onSelected: (_) => onClear(),
        ),
        for (final g in groups)
          FilterChip(
            label: Text(g.name),
            selected: groupId == g.id,
            onSelected: (_) => onGroupChanged(g.id),
          ),
        for (final r in rounds)
          FilterChip(
            label: Text(r.name),
            selected: roundId == r.id,
            onSelected: (_) => onRoundChanged(r.id),
          ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.category, required this.onChanged});

  final TournamentLeaderboardCategory category;
  final ValueChanged<TournamentLeaderboardCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    const all = [
      ...kTournamentBattingCategories,
      ...kTournamentBowlingCategories,
      ...kTournamentFieldingCategories,
      ...kTournamentTeamCategories,
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = all[i];
          return ChoiceChip(
            label: Text(c.title, style: const TextStyle(fontSize: 12)),
            selected: category == c,
            onSelected: (_) => onChanged(c),
          );
        },
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({
    required this.entries,
    required this.cf,
    this.compact = false,
  });

  final List<TournamentLeaderboardEntry> entries;
  final CfColors cf;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return TournamentOverviewEmptyInline(
        message: 'No entries for this category yet.',
      );
    }

    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${e.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: e.rank <= 3 ? cf.accent : cf.textSecondary,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: compact ? 14 : 18,
                  backgroundColor: cf.sectionBackground,
                  child: Text(
                    e.label.isNotEmpty ? e.label[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: cf.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 12 : 14,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cf.textPrimary,
                        ),
                      ),
                      if (!compact && e.subtitle.isNotEmpty)
                        Text(
                          e.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cf.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  e.valueLabel.isNotEmpty ? e.valueLabel : '${e.value}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cf.accent,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

extension _GroupFirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

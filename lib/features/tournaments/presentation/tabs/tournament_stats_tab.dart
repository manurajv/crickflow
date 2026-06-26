import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament/tournament_group_model.dart';
import '../../../../data/models/tournament/tournament_round_model.dart';
import '../../../../domain/services/tournament/tournament_analytics_models.dart';
import '../../../../shared/providers/tournament_analytics_providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../widgets/shared/tournament_async_tab.dart';
import '../widgets/tournament_module_empty_state.dart';
import '../stats/widgets/stats_dashboard_widgets.dart';
import '../stats/tournament_stats_section_screen.dart';
import '../stats/tournament_player_stats_screen.dart';

class TournamentStatsTab extends ConsumerStatefulWidget {
  const TournamentStatsTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<TournamentStatsTab> createState() => _TournamentStatsTabState();
}

class _TournamentStatsTabState extends ConsumerState<TournamentStatsTab> {
  TournamentAnalyticsScope _scope = TournamentAnalyticsScope.tournament;
  String? _groupId;
  String? _roundId;
  String _search = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TournamentAnalyticsParams get _params => TournamentAnalyticsParams(
        tournamentId: widget.tournamentId,
        filter: TournamentAnalyticsFilter(
          scope: _scope,
          groupId: _groupId,
          roundId: _roundId,
          scopeLabel: _scopeLabel(),
        ),
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
    return switch (_scope) {
      TournamentAnalyticsScope.leagueStage => 'League stage',
      TournamentAnalyticsScope.knockoutStage => 'Knockout stage',
      _ => 'Entire tournament',
    };
  }

  Future<void> _refresh() async {
    ref.invalidate(tournamentBallEventsProvider(widget.tournamentId));
    ref.invalidate(tournamentAnalyticsProvider(_params));
    try {
      await ref
          .read(tournamentAnalyticsRepositoryProvider)
          .syncTournamentAnalytics(widget.tournamentId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final groupsAsync = ref.watch(tournamentGroupsProvider(widget.tournamentId));
    final roundsAsync = ref.watch(tournamentRoundsProvider(widget.tournamentId));
    final analyticsAsync = ref.watch(tournamentAnalyticsProvider(_params));

    return TournamentAsyncTab(
      asyncValue: analyticsAsync,
      onRefresh: _refresh,
      emptyIcon: Icons.analytics_outlined,
      emptyTitle: 'No tournament statistics yet',
      emptyDescription:
          'Statistics appear once tournament matches are scored. '
          'Live updates apply as matches complete or are edited.',
      builder: (snapshot) {
        if (!snapshot.hasData) {
          return const TournamentModuleEmptyState(
            icon: Icons.analytics_outlined,
            title: 'Awaiting scored matches',
            description:
                'Complete or score a tournament match to populate analytics.',
          );
        }

        final sections = _orderedSections(snapshot);
        final filteredSections = _search.isEmpty
            ? sections
            : sections.where((id) {
                final title = id.title.toLowerCase();
                return title.contains(_search.toLowerCase());
              }).toList();

        if (filteredSections.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppDimens.screenPadding,
            children: [
              _StatsFilterBar(
                cf: cf,
                scope: _scope,
                groupId: _groupId,
                roundId: _roundId,
                groups: groupsAsync.valueOrNull ?? [],
                rounds: roundsAsync.valueOrNull ?? [],
                searchController: _searchController,
                onScopeChanged: (s) => setState(() {
                  _scope = s;
                  _groupId = null;
                  _roundId = null;
                }),
                onGroupChanged: (v) => setState(() {
                  _groupId = v;
                  _roundId = null;
                  _scope = TournamentAnalyticsScope.group;
                }),
                onRoundChanged: (v) => setState(() {
                  _roundId = v;
                  _groupId = null;
                  _scope = TournamentAnalyticsScope.round;
                }),
                onClearScope: () => setState(() {
                  _scope = TournamentAnalyticsScope.tournament;
                  _groupId = null;
                  _roundId = null;
                }),
                onSearchChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: AppDimens.spaceXl),
              Center(
                child: Text(
                  'No sections match your search.',
                  style: TextStyle(color: cf.textMuted),
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: AppDimens.screenPadding,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StatsFilterBar(
                    cf: cf,
                    scope: _scope,
                    groupId: _groupId,
                    roundId: _roundId,
                    groups: groupsAsync.valueOrNull ?? [],
                    rounds: roundsAsync.valueOrNull ?? [],
                    searchController: _searchController,
                    onScopeChanged: (s) => setState(() {
                      _scope = s;
                      _groupId = null;
                      _roundId = null;
                    }),
                    onGroupChanged: (v) => setState(() {
                      _groupId = v;
                      _roundId = null;
                      _scope = TournamentAnalyticsScope.group;
                    }),
                    onRoundChanged: (v) => setState(() {
                      _roundId = v;
                      _groupId = null;
                      _scope = TournamentAnalyticsScope.round;
                    }),
                    onClearScope: () => setState(() {
                      _scope = TournamentAnalyticsScope.tournament;
                      _groupId = null;
                      _roundId = null;
                    }),
                    onSearchChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  for (final sectionId in filteredSections)
                    StatsSectionCard(
                      sectionId: sectionId,
                      section: snapshot.sections[sectionId] ??
                          TournamentSectionSnapshot(id: sectionId),
                      onViewAll: () => _openSection(context, sectionId, snapshot),
                      onPlayerTap: (playerId) =>
                          _openPlayer(context, snapshot, playerId),
                    ),
                  const SizedBox(height: AppDimens.spaceLg),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  List<TournamentStatsSectionId> _orderedSections(
    TournamentAnalyticsSnapshot snapshot,
  ) {
    const order = TournamentStatsSectionId.values;
    return order
        .where((id) {
          final section = snapshot.sections[id];
          return section != null && section.hasContent;
        })
        .toList();
  }

  void _openSection(
    BuildContext context,
    TournamentStatsSectionId id,
    TournamentAnalyticsSnapshot snapshot,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentStatsSectionScreen(
          tournamentId: widget.tournamentId,
          sectionId: id,
          filter: _params.filter,
          initialSnapshot: snapshot,
        ),
      ),
    );
  }

  void _openPlayer(
    BuildContext context,
    TournamentAnalyticsSnapshot snapshot,
    String playerId,
  ) {
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
}

class _StatsFilterBar extends StatelessWidget {
  const _StatsFilterBar({
    required this.cf,
    required this.scope,
    required this.groupId,
    required this.roundId,
    required this.groups,
    required this.rounds,
    required this.searchController,
    required this.onScopeChanged,
    required this.onGroupChanged,
    required this.onRoundChanged,
    required this.onClearScope,
    required this.onSearchChanged,
  });

  final CfColors cf;
  final TournamentAnalyticsScope scope;
  final String? groupId;
  final String? roundId;
  final List<TournamentGroupModel> groups;
  final List<TournamentRoundModel> rounds;
  final TextEditingController searchController;
  final ValueChanged<TournamentAnalyticsScope> onScopeChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String?> onRoundChanged;
  final VoidCallback onClearScope;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search sections…',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            filled: true,
            fillColor: cf.sectionBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cf.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cf.border),
            ),
          ),
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(
                label: 'All',
                selected: scope == TournamentAnalyticsScope.tournament &&
                    groupId == null &&
                    roundId == null,
                onTap: onClearScope,
              ),
              _chip(
                label: 'League',
                selected: scope == TournamentAnalyticsScope.leagueStage,
                onTap: () => onScopeChanged(TournamentAnalyticsScope.leagueStage),
              ),
              _chip(
                label: 'Knockout',
                selected: scope == TournamentAnalyticsScope.knockoutStage,
                onTap: () =>
                    onScopeChanged(TournamentAnalyticsScope.knockoutStage),
              ),
              for (final g in groups)
                _chip(
                  label: g.name,
                  selected: groupId == g.id,
                  onTap: () => onGroupChanged(g.id),
                ),
              for (final r in rounds)
                _chip(
                  label: r.name,
                  selected: roundId == r.id,
                  onTap: () => onRoundChanged(r.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        showCheckmark: false,
        selectedColor: cf.accent.withValues(alpha: 0.15),
        checkmarkColor: cf.accent,
        side: BorderSide(
          color: selected ? cf.accent.withValues(alpha: 0.4) : cf.border,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

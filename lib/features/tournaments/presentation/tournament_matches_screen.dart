import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/tournament_match_providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import 'widgets/matches/schedule_matches_bottom_sheet.dart';
import 'widgets/matches/tournament_match_card.dart';
import 'widgets/tournament_module_empty_state.dart';

class TournamentMatchesScreen extends ConsumerStatefulWidget {
  const TournamentMatchesScreen({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  @override
  ConsumerState<TournamentMatchesScreen> createState() =>
      _TournamentMatchesScreenState();
}

class _TournamentMatchesScreenState extends ConsumerState<TournamentMatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _filters = [
    TournamentMatchFilter.live,
    TournamentMatchFilter.upcoming,
    TournamentMatchFilter.completed,
  ];

  static const _labels = ['Live', 'Upcoming', 'Completed'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final canManage = ref
        .watch(tournamentPermissionServiceProvider)
        .canManageFixtures(widget.role);
    final liveTournament =
        ref.watch(tournamentProvider(widget.tournament.id)).valueOrNull ??
        widget.tournament;
    final allMatches = ref
        .watch(tournamentMatchesProvider(widget.tournament.id))
        .valueOrNull ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: cf.surface,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: cf.accent,
                  labelColor: cf.accent,
                  unselectedLabelColor: cf.textSecondary,
                  tabs: _labels.map((l) => Tab(text: l)).toList(),
                ),
              ),
              if (canManage)
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                  child: TextButton.icon(
                    onPressed: () => showScheduleMatchesBottomSheet(
                      context: context,
                      tournament: liveTournament,
                      canManage: canManage,
                    ),
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Schedule'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: allMatches.isEmpty
              ? RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(
                      tournamentMatchesProvider(widget.tournament.id),
                    );
                  },
                  child: TournamentModuleEmptyState(
                    icon: Icons.sports_cricket_outlined,
                    title: 'No Matches Scheduled',
                    description:
                        'Create fixtures or start a match to begin the tournament.',
                    primaryAction: canManage
                        ? (
                            label: 'Schedule Matches',
                            onPressed: () => showScheduleMatchesBottomSheet(
                              context: context,
                              tournament: liveTournament,
                              canManage: canManage,
                            ),
                          )
                        : null,
                    secondaryAction: canManage
                        ? (
                            label: 'Start Match',
                            onPressed: () => context.push('/match/create'),
                          )
                        : null,
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: _filters.map((filter) {
                    final matches = ref.watch(
                      tournamentMatchesFilteredProvider(
                        (tournamentId: widget.tournament.id, filter: filter),
                      ),
                    );
                    if (matches.isEmpty) {
                      return Center(
                        child: Text(
                          'No ${_labels[_filters.indexOf(filter)].toLowerCase()} matches',
                          style: TextStyle(color: cf.textSecondary),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          tournamentMatchesProvider(widget.tournament.id),
                        );
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          top: AppDimens.spaceSm,
                          bottom: AppDimens.spaceLg,
                        ),
                        itemCount: matches.length,
                        itemBuilder: (_, i) => TournamentMatchCard(
                          match: matches[i],
                          tournamentId: widget.tournament.id,
                          canManage: canManage,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

typedef TournamentMatchesTab = TournamentMatchesScreen;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/location_filter_selection.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/my_player_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/start_match_draft_provider.dart';
import '../../../shared/widgets/location_filter_sheet.dart';
import '../../teams/presentation/utils/teams_list_filter.dart';
import '../../teams/presentation/widgets/team_list_scope.dart';
import '../../teams/presentation/widgets/teams_list_toolbar.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import '../../../core/theme/cf_colors.dart';

/// Pick a team for Team A or Team B during start-match flow.
class SelectTeamForMatchScreen extends ConsumerStatefulWidget {
  const SelectTeamForMatchScreen({
    super.key,
    required this.slotLabel,
    required this.slot,
    this.opponentsOnly = false,
  });

  final String slotLabel;
  /// `a` or `b` — which slot is being filled.
  final String slot;
  final bool opponentsOnly;

  @override
  ConsumerState<SelectTeamForMatchScreen> createState() =>
      _SelectTeamForMatchScreenState();
}

class _SelectTeamForMatchScreenState extends ConsumerState<SelectTeamForMatchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _query = '';
  List<LocationFilterSelection> _locations = const [];

  @override
  void initState() {
    super.initState();
    _resetFilters();
    _tabs = TabController(length: widget.opponentsOnly ? 1 : 3, vsync: this);
  }

  void _resetFilters() {
    _query = '';
    _locations = const [];
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty || _locations.isNotEmpty;

  void _clearFilters() => setState(_resetFilters);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final draft = ref.watch(startMatchDraftProvider);
    final blockedTeam = widget.slot == 'b' ? draft.teamA : draft.teamB;
    final blockedSlotLabel = widget.slot == 'b' ? 'Team A' : 'Team B';

    return Scaffold(
      appBar: AppBar(
        title: Text('Select ${widget.slotLabel}'),
        bottom: widget.opponentsOnly
            ? null
            : TabBar(
                controller: _tabs,
                indicatorColor: cf.accent,
                labelColor: cf.accent,
                unselectedLabelColor: cf.textSecondary,
                tabs: const [
                  Tab(text: 'Your teams'),
                  Tab(text: 'All teams'),
                  Tab(text: 'Create'),
                ],
              ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeamsSearchBar(
            query: _query,
            onChanged: (v) => setState(() => _query = v),
          ),
          _SelectTeamLocationFilterBar(
            locations: _locations,
            onLocationsChanged: (locs) => setState(() => _locations = locs),
          ),
          Expanded(
            child: widget.opponentsOnly
                ? _TeamList(
                    scope: _TeamListScope.all,
                    query: _query,
                    locations: _locations,
                    blockedTeamId: blockedTeam?.id,
                    blockedSlotLabel: blockedSlotLabel,
                    hasActiveFilters: _hasActiveFilters,
                    onClearFilters: _clearFilters,
                    onPick: (t) => context.pop(t),
                  )
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _TeamList(
                        scope: _TeamListScope.yours,
                        query: _query,
                        locations: _locations,
                        blockedTeamId: blockedTeam?.id,
                        blockedSlotLabel: blockedSlotLabel,
                        hasActiveFilters: _hasActiveFilters,
                        onClearFilters: _clearFilters,
                        onPick: (t) => context.pop(t),
                      ),
                      _TeamList(
                        scope: _TeamListScope.all,
                        query: _query,
                        locations: _locations,
                        blockedTeamId: blockedTeam?.id,
                        blockedSlotLabel: blockedSlotLabel,
                        hasActiveFilters: _hasActiveFilters,
                        onClearFilters: _clearFilters,
                        onPick: (t) => context.pop(t),
                      ),
                      const _AddTeamTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Location chip row — same shared sheet as Teams / Community.
class _SelectTeamLocationFilterBar extends StatelessWidget {
  const _SelectTeamLocationFilterBar({
    required this.locations,
    required this.onLocationsChanged,
  });

  final List<LocationFilterSelection> locations;
  final ValueChanged<List<LocationFilterSelection>> onLocationsChanged;

  bool get _locationActive => locations.isNotEmpty;

  Future<void> _open(BuildContext context) async {
    final result = await showLocationFilterSheet(
      context,
      initial: locations,
      subtitle:
          'Search or use GPS, then add locations. Teams matching any selection '
          'are shown. Clear city/province fields to broaden a filter.',
    );
    if (result == null) return;
    onLocationsChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  avatar: Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: _locationActive
                        ? cf.accent
                        : cf.textSecondary,
                  ),
                  label: const Text('Location'),
                  selected: _locationActive,
                  onSelected: (_) => _open(context),
                  selectedColor: cf.accent.withValues(alpha: 0.35),
                  checkmarkColor: cf.accent,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: _locationActive
                        ? cf.accent
                        : cf.textSecondary,
                    fontWeight:
                        _locationActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_locationActive)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      locations.length == 1
                          ? locations.first.label
                          : '${locations.length} locations',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onLocationsChanged(const []),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Which set of teams _TeamList should show.
enum _TeamListScope { yours, all }

class _TeamList extends ConsumerWidget {
  const _TeamList({
    required this.scope,
    required this.query,
    required this.locations,
    required this.blockedTeamId,
    required this.blockedSlotLabel,
    required this.hasActiveFilters,
    required this.onClearFilters,
    required this.onPick,
  });

  final _TeamListScope scope;
  final String query;
  final List<LocationFilterSelection> locations;
  final String? blockedTeamId;
  final String blockedSlotLabel;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  final void Function(TeamModel team) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(allTeamsProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final player = ref.watch(myPlayerProvider).valueOrNull;

    return teamsAsync.when(
      data: (teams) {
        // "Your teams" filters to teams the current user is a member of.
        // "All teams" shows every registered team on CrickFlow.
        final pool = scope == _TeamListScope.yours
            ? teams.where((t) {
                final memberIds = TeamsListFilter.memberTeamIds(
                  teams: teams,
                  uid: uid,
                  player: player,
                );
                return memberIds.contains(t.id);
              }).toList()
            : teams;

        final list = TeamsListFilter.apply(
          teams: pool,
          scope: TeamListScope.all,
          query: query,
          locations: locations,
        );

        if (list.isEmpty) {
          return _SelectTeamEmptyState(
            hasFilters: hasActiveFilters,
            onClearFilters: onClearFilters,
          );
        }

        return ListView.builder(
          padding: AppDimens.listPadding,
          itemCount: list.length,
          itemBuilder: (context, i) {
            final team = list[i];
            final isBlocked =
                blockedTeamId != null && team.id == blockedTeamId;
            return _SelectTeamCard(
              team: team,
              isBlocked: isBlocked,
              blockedSlotLabel: blockedSlotLabel,
              onPick: isBlocked ? null : () => onPick(team),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _SelectTeamCard extends StatelessWidget {
  const _SelectTeamCard({
    required this.team,
    required this.isBlocked,
    required this.blockedSlotLabel,
    required this.onPick,
  });

  final TeamModel team;
  final bool isBlocked;
  final String blockedSlotLabel;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);

    return Opacity(
      opacity: isBlocked ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: cf.accent,
                  backgroundImage: team.logoUrl != null
                      ? CachedNetworkImageProvider(team.logoUrl!)
                      : null,
                  child: team.logoUrl == null
                      ? Text(team.name.isNotEmpty ? team.name[0] : '?')
                      : null,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isBlocked
                              ? cf.textSecondary
                              : cf.textPrimary,
                        ),
                      ),
                      if (team.location.displayLabel.isNotEmpty)
                        Text(
                          team.location.displayLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                        ),
                      if (isBlocked) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: cf.accent.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Selected as $blockedSlotLabel',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cf.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isBlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cf.sectionBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cf.border),
                    ),
                    child: Text(
                      'Already selected',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cf.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: cf.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectTeamEmptyState extends StatelessWidget {
  const _SelectTeamEmptyState({
    required this.hasFilters,
    required this.onClearFilters,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppDimens.spaceXl),
          Icon(
            Icons.groups_outlined,
            size: 56,
            color: cf.textSecondary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'No teams found',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Try adjusting your search or location filter.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: onClearFilters,
              style: ScoringUiKit.primaryButtonStyle(context),
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddTeamTab extends StatelessWidget {
  const _AddTeamTab();

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.groups_outlined,
            size: 56,
            color: cf.textSecondary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Create a new team',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Set up your team and use it in this match.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cf.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          FilledButton.icon(
            onPressed: () => context.push('/teams/create'),
            icon: const Icon(Icons.add),
            label: const Text('Create team'),
            style: ScoringUiKit.primaryButtonStyle(context).copyWith(
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/match_card_navigation.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/player_model.dart';
import '../../../../domain/scoring/match_lifecycle.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../domain/services/profile_match_filter_service.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_match_scoring_providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../../my_cricket_filters.dart';
import '../widgets/my_cricket_action_banner.dart';
import '../widgets/my_cricket_guest_sign_in_prompt.dart';
import '../widgets/my_cricket_sort_button.dart';

class MyCricketMatchesTab extends ConsumerStatefulWidget {
  const MyCricketMatchesTab({super.key});

  @override
  ConsumerState<MyCricketMatchesTab> createState() =>
      _MyCricketMatchesTabState();
}

class _MyCricketMatchesTabState extends ConsumerState<MyCricketMatchesTab> {
  MyCricketListScope _scope = MyCricketListScope.yours;
  MyCricketMatchView _view = MyCricketMatchView.matches;
  MyCricketSort _sort = MyCricketSort.newest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null && mounted) {
        setState(() => _scope = MyCricketListScope.all);
      }
      _consumePendingScope();
    });
  }

  void _consumePendingScope() {
    final pending = ref.read(myCricketMatchesInitialScopeProvider);
    if (pending == null || !mounted) return;
    setState(() => _scope = pending);
    ref.read(myCricketMatchesInitialScopeProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MyCricketListScope?>(myCricketMatchesInitialScopeProvider, (
      prev,
      next,
    ) {
      if (next == null || !mounted) return;
      setState(() => _scope = next);
      ref.read(myCricketMatchesInitialScopeProvider.notifier).state = null;
    });

    final uid = ref.watch(authStateProvider).value?.uid;
    final isGuest = uid == null;

    if (isGuest) {
      return _GuestMatchesBody(
        scope: _scope,
        onScopeChanged: (scope) => setState(() => _scope = scope),
        sort: _sort,
        onSortChanged: (sort) => setState(() => _sort = sort),
      );
    }

    final matchesAsync = ref.watch(matchesProvider);
    final search = ref.watch(myCricketSearchProvider);
    final matchFilters = ref.watch(profileMatchFiltersProvider);
    final player = ref.watch(myPlayerProvider).valueOrNull;
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();
    final following = ref.watch(playerFollowingProvider(uid)).valueOrNull ?? [];
    final followedPlayers = FollowedPlayerRefs.fromUsers(following);
    final role =
        ref.watch(currentUserProfileProvider).valueOrNull?.role ??
        UserRole.organizer;
    final canCreate = canCreateMatches(role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCreate && _view == MyCricketMatchView.matches)
          MyCricketActionBanner(
            title: 'Want to start a match?',
            actionLabel: 'Start',
            onAction: () => context.push('/match/start'),
          ),
        _viewChips(context),
        if (_view == MyCricketMatchView.matches) _scopeChips(context),
        MyCricketSortButton(
          value: _sort,
          onChanged: (sort) => setState(() => _sort = sort),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(matchesProvider),
            child: matchesAsync.when(
              data: (matches) {
                final scoringAccessById = _view == MyCricketMatchView.scoring
                    ? {
                        for (final match in matches)
                          match.id: _scoringAccess(match, uid, role),
                      }
                    : const <String, TournamentMatchScoringAccess>{};
                var list = switch (_view) {
                  MyCricketMatchView.matches => _filter(
                    matches,
                    uid: uid,
                    player: player,
                    userTeamIds: userTeamIds,
                    followedPlayers: followedPlayers,
                  ),
                  MyCricketMatchView.scoring => matches.where((match) {
                    final access =
                        scoringAccessById[match.id] ??
                        TournamentMatchScoringAccess.none;
                    return access.canScoreLive || access.canStartSetup;
                  }).toList(),
                  MyCricketMatchView.streaming =>
                    matches
                        .where((match) => userStreamedMatch(match, uid))
                        .toList(),
                };
                if (_view == MyCricketMatchView.matches) {
                  list = filterProfileMatches(list, matchFilters);
                }
                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  list = list
                      .where(
                        (m) =>
                            m.title.toLowerCase().contains(q) ||
                            m.teamAName.toLowerCase().contains(q) ||
                            m.teamBName.toLowerCase().contains(q),
                      )
                      .toList();
                }
                list = sortMyCricketMatches(list, _sort);
                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      MatchListEmptyState(
                        message: switch (_view) {
                          MyCricketMatchView.scoring =>
                            'Matches you score will appear here',
                          MyCricketMatchView.streaming =>
                            'Matches you stream will appear here',
                          MyCricketMatchView.matches
                              when matchFilters.hasActiveFilters =>
                            'No matches match your filters',
                          MyCricketMatchView.matches => 'No matches found',
                        },
                        onClearFilters:
                            search.isNotEmpty ||
                                (_view == MyCricketMatchView.matches &&
                                    matchFilters.hasActiveFilters)
                            ? () {
                                if (search.isNotEmpty) {
                                  ref
                                          .read(
                                            myCricketSearchProvider.notifier,
                                          )
                                          .state =
                                      '';
                                }
                                if (matchFilters.hasActiveFilters) {
                                  ref
                                          .read(
                                            profileMatchFiltersProvider
                                                .notifier,
                                          )
                                          .state =
                                      const ProfileMatchFilters();
                                }
                              }
                            : null,
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final match = list[i];
                    final attribution =
                        _view == MyCricketMatchView.matches &&
                            _scope == MyCricketListScope.network
                        ? networkMatchAttribution(match, following)
                        : null;
                    final canOpenWork =
                        match.status != MatchStatus.abandoned &&
                        !MatchLifecycle.isCompleted(match);
                    final scoringAccess =
                        scoringAccessById[match.id] ??
                        TournamentMatchScoringAccess.none;
                    final String? actionLabel;
                    final VoidCallback? onAction;
                    if (_view == MyCricketMatchView.scoring &&
                        canOpenWork &&
                        (scoringAccess.canScoreLive ||
                            scoringAccess.canStartSetup)) {
                      actionLabel = 'Resume scoring';
                      onAction = () => openMatchScoring(
                        context,
                        ref: ref,
                        match: match,
                        userId: uid,
                        forceSetupStep: scoringAccess.forceSetupStep,
                      );
                    } else if (_view == MyCricketMatchView.streaming &&
                        canOpenWork) {
                      actionLabel = canResumeStreaming(match, uid)
                          ? 'Resume stream'
                          : 'Open studio';
                      onAction = () =>
                          context.push('/match/${match.id}/stream');
                    } else {
                      actionLabel = null;
                      onAction = null;
                    }
                    return MatchListCard(
                      match: match,
                      attributionLabel: attribution,
                      primaryActionLabel: actionLabel,
                      onPrimaryAction: onAction,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ),
      ],
    );
  }

  TournamentMatchScoringAccess _scoringAccess(
    MatchModel match,
    String? uid,
    UserRole role,
  ) {
    final tournamentId = match.tournamentId;
    return resolveTournamentMatchScoringAccess(
      match: match,
      userId: uid,
      role: role,
      tournament: tournamentId != null && tournamentId.isNotEmpty
          ? ref.watch(tournamentProvider(tournamentId)).valueOrNull
          : null,
      officials: tournamentId != null && tournamentId.isNotEmpty
          ? ref.watch(tournamentOfficialsProvider(tournamentId)).valueOrNull ??
                []
          : const [],
    );
  }

  Widget _viewChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          _viewChip(context, 'Matches', MyCricketMatchView.matches),
          const SizedBox(width: AppDimens.spaceXs),
          _viewChip(context, 'Scoring', MyCricketMatchView.scoring),
          const SizedBox(width: AppDimens.spaceXs),
          _viewChip(context, 'Streaming', MyCricketMatchView.streaming),
        ],
      ),
    );
  }

  Widget _viewChip(
    BuildContext context,
    String label,
    MyCricketMatchView view,
  ) {
    final cf = context.cf;
    final selected = _view == view;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _view = view),
      selectedColor: cf.accent,
      backgroundColor: cf.sectionBackground,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? cf.onAccent : cf.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _scopeChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          _scopeChip(context, 'Your', MyCricketListScope.yours),
          const SizedBox(width: AppDimens.spaceXs),
          _scopeChip(context, 'Played', MyCricketListScope.played),
          const SizedBox(width: AppDimens.spaceXs),
          _scopeChip(context, 'Network', MyCricketListScope.network),
          const SizedBox(width: AppDimens.spaceXs),
          _scopeChip(context, 'All', MyCricketListScope.all),
        ],
      ),
    );
  }

  List<MatchModel> _filter(
    List<MatchModel> matches, {
    String? uid,
    PlayerModel? player,
    required Set<String> userTeamIds,
    required FollowedPlayerRefs followedPlayers,
  }) {
    return matches
        .where(
          (m) => filterMatchByScope(
            m,
            _scope,
            uid: uid,
            player: player,
            userTeamIds: userTeamIds,
            followedPlayers: followedPlayers,
          ),
        )
        .toList();
  }

  Widget _scopeChip(
    BuildContext context,
    String label,
    MyCricketListScope scope,
  ) {
    final cf = context.cf;
    final selected = _scope == scope;
    return Material(
      color: selected ? cf.accent : cf.sectionBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => setState(() => _scope = scope),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? cf.onAccent : cf.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestMatchesBody extends ConsumerWidget {
  const _GuestMatchesBody({
    required this.scope,
    required this.onScopeChanged,
    required this.sort,
    required this.onSortChanged,
  });

  final MyCricketListScope scope;
  final ValueChanged<MyCricketListScope> onScopeChanged;
  final MyCricketSort sort;
  final ValueChanged<MyCricketSort> onSortChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (scope != MyCricketListScope.all) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _guestScopeChips(context),
          MyCricketSortButton(value: sort, onChanged: onSortChanged),
          const Expanded(child: MyCricketGuestSignInPrompt()),
        ],
      );
    }

    final matchesAsync = ref.watch(matchesProvider);
    final search = ref.watch(myCricketSearchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyCricketGuestSignInPrompt(
          compact: true,
          title: 'Sign in to view your matches',
          subtitle:
              'Browse all matches below, or sign in to see your teams, '
              'played games, and network.',
        ),
        _guestScopeChips(context),
        MyCricketSortButton(value: sort, onChanged: onSortChanged),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(matchesProvider),
            child: matchesAsync.when(
              data: (matches) {
                var list = List<MatchModel>.from(matches);

                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  list = list
                      .where(
                        (m) =>
                            m.title.toLowerCase().contains(q) ||
                            m.teamAName.toLowerCase().contains(q) ||
                            m.teamBName.toLowerCase().contains(q),
                      )
                      .toList();
                }
                list = sortMyCricketMatches(list, sort);

                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      MatchListEmptyState(message: 'No matches found'),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => MatchListCard(match: list[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _guestScopeChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          _guestScopeChip(context, 'Your', MyCricketListScope.yours),
          const SizedBox(width: AppDimens.spaceXs),
          _guestScopeChip(context, 'Played', MyCricketListScope.played),
          const SizedBox(width: AppDimens.spaceXs),
          _guestScopeChip(context, 'Network', MyCricketListScope.network),
          const SizedBox(width: AppDimens.spaceXs),
          _guestScopeChip(context, 'All', MyCricketListScope.all),
        ],
      ),
    );
  }

  Widget _guestScopeChip(
    BuildContext context,
    String label,
    MyCricketListScope value,
  ) {
    final cf = context.cf;
    final selected = scope == value;
    return Material(
      color: selected ? cf.accent : cf.sectionBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onScopeChanged(value),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? cf.onAccent : cf.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

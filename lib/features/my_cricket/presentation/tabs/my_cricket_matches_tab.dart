import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/player_model.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../domain/services/profile_match_filter_service.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../../my_cricket_filters.dart';
import '../widgets/my_cricket_action_banner.dart';
import '../widgets/my_cricket_guest_sign_in_prompt.dart';

class MyCricketMatchesTab extends ConsumerStatefulWidget {
  const MyCricketMatchesTab({super.key});

  @override
  ConsumerState<MyCricketMatchesTab> createState() =>
      _MyCricketMatchesTabState();
}

class _MyCricketMatchesTabState extends ConsumerState<MyCricketMatchesTab> {
  MyCricketListScope _scope = MyCricketListScope.yours;

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
    ref.listen<MyCricketListScope?>(myCricketMatchesInitialScopeProvider,
        (prev, next) {
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
      );
    }

    final matchesAsync = ref.watch(matchesProvider);
    final search = ref.watch(myCricketSearchProvider);
    final matchFilters = ref.watch(profileMatchFiltersProvider);
    final player = ref.watch(myPlayerProvider).valueOrNull;
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();
    final following =
        ref.watch(playerFollowingProvider(uid)).valueOrNull ?? [];
    final followedPlayers = FollowedPlayerRefs.fromUsers(following);
    final canCreate = canCreateMatches(
      ref.watch(currentUserProfileProvider).valueOrNull?.role ??
          UserRole.organizer,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCreate)
          MyCricketActionBanner(
            title: 'Want to start a match?',
            actionLabel: 'Start',
            onAction: () => context.push('/match/create'),
          ),
        _scopeChips(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(matchesProvider),
            child: matchesAsync.when(
              data: (matches) {
                var list = _filter(
                  matches,
                  uid: uid,
                  player: player,
                  userTeamIds: userTeamIds,
                  followedPlayers: followedPlayers,
                );
                list = filterProfileMatches(list, matchFilters);
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
                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      MatchListEmptyState(
                        message: matchFilters.hasActiveFilters
                            ? 'No matches match your filters'
                            : 'No matches found',
                        onClearFilters: search.isNotEmpty ||
                                matchFilters.hasActiveFilters
                            ? () {
                                if (search.isNotEmpty) {
                                  ref
                                      .read(myCricketSearchProvider.notifier)
                                      .state = '';
                                }
                                if (matchFilters.hasActiveFilters) {
                                  ref
                                      .read(
                                        profileMatchFiltersProvider.notifier,
                                      )
                                      .state = const ProfileMatchFilters();
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
                    final attribution = _scope == MyCricketListScope.network
                        ? networkMatchAttribution(match, following)
                        : null;
                    return MatchListCard(
                      match: match,
                      attributionLabel: attribution,
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ),
      ],
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
  });

  final MyCricketListScope scope;
  final ValueChanged<MyCricketListScope> onScopeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (scope != MyCricketListScope.all) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _guestScopeChips(context),
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

                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      MatchListEmptyState(
                        message: 'No matches found',
                      ),
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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

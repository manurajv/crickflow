import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_gate.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/guest_device_location_provider.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/location_filter_bar.dart';
import '../../../../shared/widgets/tournament_list_card.dart';
import '../../my_cricket_filters.dart';
import '../widgets/my_cricket_action_banner.dart';
import '../widgets/my_cricket_guest_sign_in_prompt.dart';

class MyCricketTournamentsTab extends ConsumerStatefulWidget {
  const MyCricketTournamentsTab({super.key});

  @override
  ConsumerState<MyCricketTournamentsTab> createState() =>
      _MyCricketTournamentsTabState();
}

class _MyCricketTournamentsTabState extends ConsumerState<MyCricketTournamentsTab> {
  MyCricketListScope _scope = MyCricketListScope.yours;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null && mounted) {
        setState(() => _scope = MyCricketListScope.all);
      }
    });
  }

  void _registerTournament() {
    requireAuthVoid(
      context: context,
      ref: ref,
      returnPath: '/matches',
      action: () => context.push('/tournaments/create'),
    );
  }

  void _openTournament(TournamentModel tournament) {
    context.push('/tournaments/${tournament.id}');
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final isGuest = uid == null;

    if (isGuest) {
      return _GuestTournamentsBody(
        scope: _scope,
        onScopeChanged: (scope) => setState(() => _scope = scope),
        onOpenTournament: _openTournament,
      );
    }

    final tournamentsAsync = ref.watch(tournamentsProvider);
    final search = ref.watch(myCricketSearchProvider);
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();
    final following =
        ref.watch(playerFollowingProvider(uid)).valueOrNull ?? [];
    final followedPlayers = FollowedPlayerRefs.fromUsers(following);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyCricketActionBanner(
          title: 'Want to host a tournament?',
          actionLabel: 'Register',
          onAction: _registerTournament,
        ),
        _scopeChips(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(tournamentsProvider),
            child: tournamentsAsync.when(
              data: (all) {
                var list = all
                    .where(
                      (t) => filterTournamentByScope(
                        t,
                        _scope,
                        uid: uid,
                        userTeamIds: userTeamIds,
                        followedPlayers: followedPlayers,
                      ),
                    )
                    .toList();

                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  list = list
                      .where((t) => t.name.toLowerCase().contains(q))
                      .toList();
                }

                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Text(
                          search.isNotEmpty
                              ? 'No tournaments match your search'
                              : 'No tournaments in this filter',
                          style: TextStyle(color: context.cf.textSecondary),
                        ),
                      ),
                      if (search.isNotEmpty)
                        Center(
                          child: TextButton(
                            onPressed: () {
                              ref.read(myCricketSearchProvider.notifier).state =
                                  '';
                            },
                            child: const Text('Clear search'),
                          ),
                        ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    return TournamentListCard(
                      tournament: t,
                      onTap: () => _openTournament(t),
                      trailing: t.tournamentCode != null
                          ? Text(
                              t.tournamentCode!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: context.cf.accent),
                            )
                          : null,
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

class _GuestTournamentsBody extends ConsumerWidget {
  const _GuestTournamentsBody({
    required this.scope,
    required this.onScopeChanged,
    required this.onOpenTournament,
  });

  final MyCricketListScope scope;
  final ValueChanged<MyCricketListScope> onScopeChanged;
  final void Function(TournamentModel) onOpenTournament;

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

    final tournamentsAsync = ref.watch(tournamentsProvider);
    final locationAsync = ref.watch(guestDeviceLocationProvider);
    final search = ref.watch(myCricketSearchProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MyCricketGuestSignInPrompt(
          compact: true,
          title: 'Sign in to view your tournaments',
          subtitle:
              'Browse nearby tournaments below, or sign in to see your teams '
              'and network.',
        ),
        _guestScopeChips(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tournamentsProvider);
              ref.invalidate(guestDeviceLocationProvider);
            },
            child: tournamentsAsync.when(
              data: (all) => locationAsync.when(
                data: (location) {
                  if (location == null || location.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 48),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Enable location access to see tournaments near you.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  var list = all
                      .where(
                        (t) => locationMatchesFilter(
                          t.location,
                          location.country,
                          location.city,
                        ),
                      )
                      .toList();

                  if (search.isNotEmpty) {
                    final q = search.toLowerCase();
                    list = list
                        .where((t) => t.name.toLowerCase().contains(q))
                        .toList();
                  }

                  if (list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            'Tournaments near ${location.displayLabel}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Center(
                          child: Text(
                            'No tournaments found near your location',
                            style: TextStyle(color: context.cf.textSecondary),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: list.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            'Tournaments near ${location.displayLabel}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        );
                      }
                      final t = list[i - 1];
                      return TournamentListCard(
                        tournament: t,
                        onTap: () => onOpenTournament(t),
                        trailing: t.tournamentCode != null
                            ? Text(
                                t.tournamentCode!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: context.cf.accent),
                              )
                            : null,
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/navigation/tournament_join_navigation.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/team_leadership_utils.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/tournament/tournament_team_request_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/my_player_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/providers/tournament_team_request_provider.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../teams/presentation/widgets/team_list_tile.dart';
import 'utils/tournament_join_utils.dart';

class TournamentJoinScreen extends ConsumerStatefulWidget {
  const TournamentJoinScreen({
    super.key,
    required this.tournamentId,
    this.fromExternalLink = false,
  });

  final String tournamentId;
  final bool fromExternalLink;

  @override
  ConsumerState<TournamentJoinScreen> createState() =>
      _TournamentJoinScreenState();
}

class _TournamentJoinScreenState extends ConsumerState<TournamentJoinScreen> {
  String? _selectedTeamId;
  bool _submitting = false;

  void _handleBack() {
    if (widget.fromExternalLink || !context.canPop()) {
      goToMyCricketTournamentsTab(ref, context);
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final tournamentAsync = ref.watch(tournamentProvider(widget.tournamentId));
    final teamsAsync = ref.watch(allTeamsProvider);
    final playerAsync = ref.watch(myPlayerProvider);
    final requestsAsync =
        ref.watch(tournamentTeamRequestsProvider(widget.tournamentId));
    final uid = ref.watch(authStateProvider).value?.uid;
    final role = ref.watch(
      tournamentMemberRoleProvider((widget.tournamentId, uid)),
    );

    return PopScope(
      canPop: !widget.fromExternalLink && context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: CfChromeAppBar(
          title: const Text('Join tournament'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: tournamentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (tournament) {
            if (tournament == null) {
              return const Center(child: Text('Tournament not found'));
            }

            if (uid == null) {
              return _SignInPrompt(tournament: tournament);
            }

            final canManageTournament = role == TournamentRole.owner ||
                role == TournamentRole.admin ||
                tournament.effectiveOrganizerId == uid;

            if (canManageTournament) {
              return _OrganizerBody(
                tournament: tournament,
                onManageTeams: () =>
                    context.go('/tournaments/${tournament.id}/teams'),
                onViewDashboard: () =>
                    context.go('/tournaments/${tournament.id}'),
              );
            }

            return teamsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (allTeams) {
                final player = playerAsync.valueOrNull;
                final leadershipTeams = TeamLeadershipUtils.leadershipTeams(
                  teams: allTeams,
                  uid: uid,
                  player: player,
                );
                final requests = requestsAsync.valueOrNull ?? [];
                final requestByTeamId = TournamentJoinUtils.requestMap(requests);

                if (leadershipTeams.isEmpty) {
                  return _NoLeadershipBody(tournament: tournament);
                }

                final eligibleTeams = TournamentJoinUtils.selectableJoinTeams(
                  tournament: tournament,
                  leadershipTeams: leadershipTeams,
                  requestByTeamId: requestByTeamId,
                );

                final selectedTeam = _resolveSelectedTeam(
                  eligibleTeams,
                  requestByTeamId,
                );
                final activeTeamId = _selectedTeamId ?? selectedTeam?.id;

                return ListView(
                  padding: AppDimens.screenPadding,
                  children: [
                    _TournamentHeader(tournament: tournament),
                    const SizedBox(height: AppDimens.spaceMd),
                    Text(
                      'Choose a team you manage, then request to join. '
                      'The organizer must approve before your team is added.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                    if (eligibleTeams.isEmpty)
                      _AllTeamsHandledState(
                        tournament: tournament,
                        requests: requests,
                        leadershipTeams: leadershipTeams,
                      )
                    else ...[
                      Text(
                        'Your teams',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      ...eligibleTeams.map(
                        (team) => _TeamChoiceTile(
                          team: team,
                          groupValue: activeTeamId,
                          request: requestByTeamId[team.id],
                          onTap: () =>
                              setState(() => _selectedTeamId = team.id),
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      CfButton(
                        label: _submitLabel(
                          eligibleTeams
                              .cast<TeamModel?>()
                              .firstWhere(
                                (t) => t?.id == activeTeamId,
                                orElse: () => null,
                              ),
                          requestByTeamId,
                        ),
                        isGold: true,
                        isLoading: _submitting,
                        onPressed: activeTeamId == null || _submitting
                            ? null
                            : () {
                                final team = eligibleTeams.firstWhere(
                                  (t) => t.id == activeTeamId,
                                );
                                _requestJoin(
                                  tournament: tournament,
                                  team: team,
                                  existingRequest: requestByTeamId[team.id],
                                );
                              },
                      ),
                    ],
                    const SizedBox(height: AppDimens.spaceMd),
                    OutlinedButton(
                      onPressed: () =>
                          context.go('/tournaments/${tournament.id}'),
                      child: const Text('View tournament'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  TeamModel? _resolveSelectedTeam(
    List<TeamModel> eligibleTeams,
    Map<String, TournamentTeamRequestModel> requestByTeamId,
  ) {
    if (eligibleTeams.isEmpty) return null;
    if (_selectedTeamId != null) {
      for (final team in eligibleTeams) {
        if (team.id == _selectedTeamId) return team;
      }
    }
    if (eligibleTeams.length == 1) return eligibleTeams.first;
    return eligibleTeams.cast<TeamModel?>().firstWhere(
          (team) => requestByTeamId[team!.id]?.isPending ?? false,
          orElse: () => null,
        );
  }

  String _submitLabel(
    TeamModel? team,
    Map<String, TournamentTeamRequestModel> requestByTeamId,
  ) {
    if (team == null) return 'Select a team';
    final request = requestByTeamId[team.id];
    if (request?.isPending ?? false) return 'Request pending';
    return 'Request to join with ${team.name}';
  }

  Future<void> _requestJoin({
    required TournamentModel tournament,
    required TeamModel team,
    TournamentTeamRequestModel? existingRequest,
  }) async {
    if (existingRequest?.isPending ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A join request for ${team.name} is already pending'),
        ),
      );
      return;
    }

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(tournamentTeamRequestRepositoryProvider).createJoinRequest(
            tournament: tournament,
            team: team,
            requesterUserId: uid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join request sent for ${team.name}')),
      );
      goToMyCricketTournamentsTab(ref, context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _TournamentHeader extends StatelessWidget {
  const _TournamentHeader({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tournament.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (tournament.location.displayLabel.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            tournament.location.displayLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ],
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppDimens.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tournament.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            const Text('Sign in to request joining this tournament.'),
            const SizedBox(height: AppDimens.spaceLg),
            CfButton(
              label: 'Sign in',
              isGold: true,
              onPressed: () => context.push('/login'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizerBody extends StatelessWidget {
  const _OrganizerBody({
    required this.tournament,
    required this.onManageTeams,
    required this.onViewDashboard,
  });

  final TournamentModel tournament;
  final VoidCallback onManageTeams;
  final VoidCallback onViewDashboard;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView(
      padding: AppDimens.screenPadding,
      children: [
        _TournamentHeader(tournament: tournament),
        const SizedBox(height: AppDimens.spaceLg),
        Text(
          'You organize this tournament. Add teams from the Teams tab or '
          'share your invite link with other squads.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        CfButton(
          label: 'Manage teams',
          isGold: true,
          onPressed: onManageTeams,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        OutlinedButton(
          onPressed: onViewDashboard,
          child: const Text('Open tournament dashboard'),
        ),
      ],
    );
  }
}

class _NoLeadershipBody extends StatelessWidget {
  const _NoLeadershipBody({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView(
      padding: AppDimens.screenPadding,
      children: [
        _TournamentHeader(tournament: tournament),
        const SizedBox(height: AppDimens.spaceLg),
        Text(
          'Only a team owner, captain, or vice captain can request to join '
          'this tournament.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        OutlinedButton(
          onPressed: () => context.go('/tournaments/${tournament.id}'),
          child: const Text('View tournament'),
        ),
      ],
    );
  }
}

class _AllTeamsHandledState extends StatelessWidget {
  const _AllTeamsHandledState({
    required this.tournament,
    required this.requests,
    required this.leadershipTeams,
  });

  final TournamentModel tournament;
  final List<TournamentTeamRequestModel> requests;
  final List<TeamModel> leadershipTeams;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your teams',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        ...leadershipTeams.map((team) {
          final request = requests.cast<TournamentTeamRequestModel?>().firstWhere(
                (r) => r?.teamId == team.id,
                orElse: () => null,
              );
          final status = tournament.teamIds.contains(team.id)
              ? 'Already in tournament'
              : switch (request?.status) {
                  TournamentTeamRequestStatus.pending => 'Request pending',
                  TournamentTeamRequestStatus.approved => 'Approved',
                  TournamentTeamRequestStatus.rejected => 'Request declined',
                  TournamentTeamRequestStatus.withdrawn => 'Withdrawn',
                  null => 'Not requested',
                };
          return Card(
            margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
            child: ListTile(
              leading: TeamLogoAvatar(team: team, size: 44),
              title: Text(team.name),
              subtitle: Text(
                status,
                style: TextStyle(color: cf.textSecondary),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TeamChoiceTile extends StatelessWidget {
  const _TeamChoiceTile({
    required this.team,
    required this.groupValue,
    required this.request,
    required this.onTap,
  });

  final TeamModel team;
  final String? groupValue;
  final TournamentTeamRequestModel? request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final subtitle = switch (request?.status) {
      TournamentTeamRequestStatus.pending => 'Request pending approval',
      TournamentTeamRequestStatus.rejected => 'Previous request declined',
      TournamentTeamRequestStatus.withdrawn => 'Tap to request again',
      _ => 'Owner, captain, or vice captain',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: groupValue == team.id ? cf.accent : cf.border,
          width: groupValue == team.id ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: TeamLogoAvatar(team: team, size: 44),
        title: Text(team.name),
        subtitle: Text(subtitle),
        trailing: groupValue == team.id
            ? Icon(Icons.check_circle, color: cf.accent)
            : Icon(Icons.circle_outlined, color: cf.textMuted),
      ),
    );
  }
}

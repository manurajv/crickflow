import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/routes/app_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/team_leadership_utils.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/tournament/tournament_team_request_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/providers/tournament_team_request_provider.dart';
import '../../../data/repositories/tournament_team_request_repository.dart';
import '../../../shared/widgets/cf_button.dart';
import 'widgets/teams/add_team_bottom_sheet.dart';
import 'widgets/teams/tournament_team_card.dart';
import 'widgets/teams/tournament_team_confirm_sheet.dart';

class TournamentTeamsScreen extends ConsumerWidget {
  const TournamentTeamsScreen({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref
        .watch(tournamentPermissionServiceProvider)
        .canManageTeams(role);
    final liveTournament =
        ref.watch(tournamentProvider(tournament.id)).valueOrNull ?? tournament;
    final requestsAsync =
        ref.watch(tournamentTeamRequestsProvider(liveTournament.id));
    final teamsAsync = ref.watch(allTeamsProvider);
    final uid = ref.watch(authStateProvider).value?.uid;

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (requests) {
        final allTeams = teamsAsync.valueOrNull ?? [];
        final teamById = {for (final t in allTeams) t.id: t};

        final approved = requests
            .where((r) => r.displayStatus == TournamentTeamDisplayStatus.approved)
            .toList();
        final pendingJoin = requests
            .where(
              (r) =>
                  r.displayStatus == TournamentTeamDisplayStatus.pendingApproval,
            )
            .toList();
        final invited = requests
            .where((r) => r.displayStatus == TournamentTeamDisplayStatus.invited)
            .toList();
        final rejected = requests
            .where((r) => r.displayStatus == TournamentTeamDisplayStatus.rejected)
            .toList();

        final legacyApproved = liveTournament.pointsTable
            .where(
              (e) => !requests.any(
                (r) =>
                    r.teamId == e.teamId &&
                    r.displayStatus == TournamentTeamDisplayStatus.approved,
              ),
            )
            .map(
              (e) => TournamentTeamRequestModel(
                id: TournamentTeamRequestRepository.docId(
                  liveTournament.id,
                  e.teamId,
                ),
                tournamentId: liveTournament.id,
                teamId: e.teamId,
                teamName: e.teamName,
                requestType: TournamentTeamRequestType.joinRequest,
                status: TournamentTeamRequestStatus.approved,
                requestedByUserId: '',
              ),
            )
            .toList();

        final allApproved = [...approved, ...legacyApproved];
        final hasAny = requests.isNotEmpty || legacyApproved.isNotEmpty;

        if (!hasAny) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tournamentTeamRequestsProvider(liveTournament.id));
              ref.invalidate(tournamentProvider(liveTournament.id));
              ref.invalidate(allTeamsProvider);
            },
            child: _EmptyTeamsState(
              canManage: canManage,
              onAddTeam: () => showAddTeamToTournamentSheet(
                context: context,
                ref: ref,
                tournament: liveTournament,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tournamentTeamRequestsProvider(liveTournament.id));
            ref.invalidate(tournamentProvider(liveTournament.id));
            ref.invalidate(allTeamsProvider);
          },
          child: ListView(
            padding: AppDimens.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (canManage) ...[
                CfButton(
                  label: 'Add team',
                  isGold: true,
                  compact: true,
                  onPressed: () => showAddTeamToTournamentSheet(
                    context: context,
                    ref: ref,
                    tournament: liveTournament,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
              ],
              if (allApproved.isNotEmpty)
                _Section(
                  title: 'Approved teams',
                  child: Column(
                    children: allApproved
                        .map(
                          (r) => _TournamentTeamRequestRow(
                            liveTournament: liveTournament,
                            request: r,
                            fallbackTeam: teamById[r.teamId],
                            canManage: canManage,
                            uid: uid,
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (pendingJoin.isNotEmpty)
                _Section(
                  title: 'Pending requests',
                  child: Column(
                    children: pendingJoin
                        .map(
                          (r) => _TournamentTeamRequestRow(
                            liveTournament: liveTournament,
                            request: r,
                            fallbackTeam: teamById[r.teamId],
                            canManage: canManage,
                            uid: uid,
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (invited.isNotEmpty)
                _Section(
                  title: 'Invited teams',
                  child: Column(
                    children: invited
                        .map(
                          (r) => _TournamentTeamRequestRow(
                            liveTournament: liveTournament,
                            request: r,
                            fallbackTeam: teamById[r.teamId],
                            canManage: canManage,
                            uid: uid,
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (rejected.isNotEmpty)
                _Section(
                  title: 'Rejected',
                  child: Column(
                    children: rejected
                        .map(
                          (r) => _TournamentTeamRequestRow(
                            liveTournament: liveTournament,
                            request: r,
                            fallbackTeam: teamById[r.teamId],
                            canManage: canManage,
                            uid: uid,
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: AppDimens.spaceLg),
            ],
          ),
        );
      },
    );
  }
}

class _TournamentTeamRequestRow extends ConsumerWidget {
  const _TournamentTeamRequestRow({
    required this.liveTournament,
    required this.request,
    required this.fallbackTeam,
    required this.canManage,
    required this.uid,
  });

  final TournamentModel liveTournament;
  final TournamentTeamRequestModel request;
  final TeamModel? fallbackTeam;
  final bool canManage;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchedTeam = ref.watch(teamByIdProvider(request.teamId)).valueOrNull;
    final team = watchedTeam ?? fallbackTeam;

    final resolvedTeam = team ??
        TeamModel(
          id: request.teamId,
          name: request.teamName.isEmpty ? 'Team' : request.teamName,
        );

    final canRespondInvite = uid != null &&
        request.requestType == TournamentTeamRequestType.invitation &&
        request.isPending &&
        TeamLeadershipUtils.canManageJoinRequests(uid, resolvedTeam);

    final canWithdrawJoin = uid != null &&
        request.requestType == TournamentTeamRequestType.joinRequest &&
        request.isPending &&
        TeamLeadershipUtils.canManageJoinRequests(uid, resolvedTeam);

    final canRespondJoin = canManage &&
        request.requestType == TournamentTeamRequestType.joinRequest &&
        request.isPending;

    Widget? trailing;
    if (canRespondJoin) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Approve',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _approveJoin(context, ref, resolvedTeam),
          ),
          IconButton(
            tooltip: 'Reject',
            icon: const Icon(Icons.cancel_outlined),
            onPressed: () => _rejectJoin(context, ref, resolvedTeam),
          ),
        ],
      );
    } else if (canWithdrawJoin) {
      trailing = IconButton(
        tooltip: 'Withdraw request',
        icon: const Icon(Icons.undo_outlined),
        onPressed: () => _withdraw(context, ref, resolvedTeam),
      );
    } else if (canRespondInvite) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Accept',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => _acceptInvite(context, ref, resolvedTeam),
          ),
          IconButton(
            tooltip: 'Reject',
            icon: const Icon(Icons.cancel_outlined),
            onPressed: () => _rejectInvite(context, ref, resolvedTeam),
          ),
        ],
      );
    } else if (canManage &&
        request.displayStatus == TournamentTeamDisplayStatus.approved) {
      trailing = IconButton(
        tooltip: 'Remove team',
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: () => _removeTeam(context, ref),
      );
    } else if (canManage &&
        request.displayStatus == TournamentTeamDisplayStatus.rejected) {
      trailing = IconButton(
        tooltip: 'Resend invitation',
        icon: const Icon(Icons.refresh),
        onPressed: () => _resend(context, ref, resolvedTeam),
      );
    }

    return TournamentTeamCard(
      team: resolvedTeam,
      displayStatus: request.displayStatus,
      playerCount: team?.memberCount,
      trailing: trailing,
    );
  }

  Future<void> _approveJoin(
    BuildContext context,
    WidgetRef ref,
    TeamModel resolvedTeam,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final teamName =
        request.teamName.isEmpty ? resolvedTeam.name : request.teamName;
    final sheetContext = rootNavigatorKey.currentContext ?? context;
    final confirmed = await showTournamentTeamConfirmSheet(
      context: sheetContext,
      title: 'Approve join request?',
      message:
          'Add $teamName to ${liveTournament.name}? The team will appear under Approved teams.',
      confirmLabel: 'Approve',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(tournamentTeamRequestRepositoryProvider).approveJoinRequest(
            request: request,
            tournament: liveTournament,
            resolverUserId: uid,
          );
      ref.invalidate(tournamentTeamRequestsProvider(liveTournament.id));
      ref.invalidate(tournamentProvider(liveTournament.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$teamName approved')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rejectJoin(
    BuildContext context,
    WidgetRef ref,
    TeamModel resolvedTeam,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final teamName =
        request.teamName.isEmpty ? resolvedTeam.name : request.teamName;
    final sheetContext = rootNavigatorKey.currentContext ?? context;
    final confirmed = await showTournamentTeamConfirmSheet(
      context: sheetContext,
      title: 'Reject join request?',
      message: 'Decline the join request from $teamName?',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(tournamentTeamRequestRepositoryProvider).rejectJoinRequest(
            request: request,
            tournament: liveTournament,
            resolverUserId: uid,
          );
      ref.invalidate(tournamentTeamRequestsProvider(liveTournament.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join request from $teamName declined')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _acceptInvite(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(tournamentTeamRequestRepositoryProvider).acceptInvitation(
            request: request,
            team: team,
            resolverUserId: uid,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rejectInvite(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(tournamentTeamRequestRepositoryProvider).rejectInvitation(
            request: request,
            team: team,
            resolverUserId: uid,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _removeTeam(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final teamName =
        request.teamName.isEmpty ? 'this team' : request.teamName;
    final sheetContext = rootNavigatorKey.currentContext ?? context;
    final confirmed = await showTournamentTeamConfirmSheet(
      context: sheetContext,
      title: 'Remove team?',
      message:
          'Remove $teamName from ${liveTournament.name}? This cannot be undone from the teams tab.',
      confirmLabel: 'Remove team',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(tournamentTeamRequestRepositoryProvider)
          .removeApprovedTeam(
            tournament: liveTournament,
            teamId: request.teamId,
            resolverUserId: uid,
          );
      ref.invalidate(tournamentTeamRequestsProvider(liveTournament.id));
      ref.invalidate(tournamentProvider(liveTournament.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$teamName removed')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(tournamentTeamRequestRepositoryProvider).withdrawJoinRequest(
            request: request,
            team: team,
            userId: uid,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _resend(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(tournamentTeamRequestRepositoryProvider).resendInvitation(
            tournament: liveTournament,
            team: team,
            organizerUserId: uid,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation resent to ${team.name}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _EmptyTeamsState extends StatelessWidget {
  const _EmptyTeamsState({
    required this.canManage,
    required this.onAddTeam,
  });

  final bool canManage;
  final VoidCallback onAddTeam;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppDimens.screenPadding,
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.groups_outlined,
          size: 72,
          color: cf.textMuted.withValues(alpha: 0.45),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          'No teams yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          canManage
              ? 'Add teams by sharing your join link, searching existing teams, or creating a new one.'
              : 'Teams will appear here once the organiser adds them or they join the tournament.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        if (canManage) ...[
          const SizedBox(height: AppDimens.spaceXl),
          CfButton(label: 'Add team', isGold: true, onPressed: onAddTeam),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        child,
        const SizedBox(height: AppDimens.spaceMd),
      ],
    );
  }
}

/// Backward-compatible export for dashboard tab wiring.
typedef TournamentTeamsTab = TournamentTeamsScreen;

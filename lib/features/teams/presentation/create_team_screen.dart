import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/providers/tournament_team_request_provider.dart';
import '../../../config/routes/app_router.dart';
import '../../tournaments/presentation/widgets/teams/tournament_team_confirm_sheet.dart';
import 'widgets/create_team_form.dart';

/// Standalone screen that hosts the create-team form.
/// Optional [tournamentId] auto-adds the new team to that tournament for organizers.
/// Optional [seriesId] (Orgs): the same team is created, then added to the org
/// as an org team (series_clubs, linkedTeamId). The org then manages its name
/// and squad.
class CreateTeamScreen extends ConsumerWidget {
  const CreateTeamScreen({super.key, this.tournamentId, this.seriesId});

  final String? tournamentId;
  final String? seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final orgId = seriesId;
    final form = CreateTeamForm(
      navigateToTeamDetailOnCreate: tournamentId == null && orgId == null,
      onCreated: (teamId) => orgId != null
          ? _onOrgTeamCreated(context, ref, orgId, teamId)
          : _onTeamCreated(context, ref, teamId),
    );
    return Scaffold(
      backgroundColor: cf.background,
      appBar: AppBar(
        title: Text(
          orgId != null
              ? 'Create org team'
              : tournamentId == null
              ? 'Create team'
              : 'Create team for tournament',
        ),
        centerTitle: false,
      ),
      body: orgId == null
          ? form
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OrgTeamHeader(seriesId: orgId),
                Expanded(child: form),
              ],
            ),
    );
  }

  Future<void> _onOrgTeamCreated(
    BuildContext context,
    WidgetRef ref,
    String seriesId,
    String teamId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final org = ref.read(seriesByIdProvider(seriesId)).valueOrNull;
    final orgLabel = org?.kind.label ?? 'org';
    try {
      final team = await ref.read(teamRepositoryProvider).getTeam(teamId);
      final result = await ref
          .read(seriesFunctionsServiceProvider)
          .createSeriesClub({
            'seriesId': seriesId,
            'name': team?.name ?? '',
            'linkedTeamId': teamId,
          });
      if (!context.mounted) return;
      final clubId = result['clubId']?.toString() ?? '';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result['autoApproved'] == true
                ? 'Team created and added to ${org?.name ?? 'the $orgLabel'}'
                : 'Team created and sent for $orgLabel admin approval',
          ),
        ),
      );
      context.go(
        clubId.isEmpty
            ? '/series/$seriesId'
            : '/series/$seriesId/clubs/$clubId',
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Team created, but it could not be added to the $orgLabel: '
            '${e.message ?? e.code}',
          ),
        ),
      );
      context.go('/teams/$teamId');
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Team created, but it could not be added to the $orgLabel. '
            'Try again from the org.',
          ),
        ),
      );
      context.go('/teams/$teamId');
    }
  }

  Future<void> _onTeamCreated(
    BuildContext context,
    WidgetRef ref,
    String teamId,
  ) async {
    final tournamentId = this.tournamentId;
    if (tournamentId == null) {
      if (context.canPop()) context.pop();
      return;
    }

    final uid = ref.read(authStateProvider).value?.uid;
    final tournament = await ref.read(tournamentProvider(tournamentId).future);
    final team = await ref.read(teamRepositoryProvider).getTeam(teamId);
    if (uid == null || tournament == null || team == null) {
      if (context.mounted && context.canPop()) context.pop();
      return;
    }

    try {
      await ref
          .read(tournamentTeamRequestRepositoryProvider)
          .addTeamDirectlyAsOrganizer(
            tournament: tournament,
            team: team,
            organizerUserId: uid,
          );
      if (!context.mounted) return;
      context.go('/tournaments/$tournamentId/teams');
      await showTournamentTeamAddedSheet(
        context: rootNavigatorKey.currentContext ?? context,
        title: 'Team added',
        message: '${team.name} is now in ${tournament.name}.',
        sectionHint: 'See them under Approved teams below.',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      context.go('/teams/$teamId');
    }
  }
}

class _OrgTeamHeader extends ConsumerWidget {
  const _OrgTeamHeader({required this.seriesId});
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final org = ref.watch(seriesByIdProvider(seriesId)).valueOrNull;
    final role = ref.watch(mySeriesRoleProvider(seriesId));
    final isManager =
        role == SeriesRole.superAdmin || role == SeriesRole.seriesAdmin;
    final orgName = org?.name ?? 'this org';
    return Container(
      key: const Key('org_team_create_header'),
      color: cf.accent.withValues(alpha: cf.isLight ? 0.08 : 0.14),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Text(
        '${isManager ? 'Adds to' : 'Requests to join'} $orgName. '
        'This is a normal CrickFlow team you can use anywhere, but its name '
        'and squad are then managed by the org'
        '${isManager ? '.' : ' (an org admin approves the team first).'}',
        style: TextStyle(color: cf.textSecondary, fontSize: 13),
      ),
    );
  }
}

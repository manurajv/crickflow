import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/providers/tournament_team_request_provider.dart';
import '../../../config/routes/app_router.dart';
import '../../tournaments/presentation/widgets/teams/tournament_team_confirm_sheet.dart';
import 'widgets/create_team_form.dart';

/// Standalone screen that hosts the create-team form.
/// Optional [tournamentId] auto-adds the new team to that tournament for organizers.
class CreateTeamScreen extends ConsumerWidget {
  const CreateTeamScreen({super.key, this.tournamentId});

  final String? tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    return Scaffold(
      backgroundColor: cf.background,
      appBar: AppBar(
        title: Text(
          tournamentId == null ? 'Create team' : 'Create team for tournament',
        ),
        centerTitle: false,
      ),
      body: CreateTeamForm(
        navigateToTeamDetailOnCreate: tournamentId == null,
        onCreated: (teamId) => _onTeamCreated(context, ref, teamId),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      context.go('/teams/$teamId');
    }
  }
}

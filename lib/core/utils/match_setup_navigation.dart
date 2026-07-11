import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/enums.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_setup_draft_models.dart';
import '../../domain/scoring/match_lifecycle.dart';
import '../../domain/scoring/toss_team_policy.dart';
import '../../domain/services/tournament/tournament_official_assign_service.dart';
import '../../shared/providers/providers.dart';
import '../../shared/providers/offline_sync_provider.dart';
import '../../shared/providers/start_match_draft_provider.dart';
import '../../shared/providers/tournament_providers.dart';

/// Step indices for the create-match wizard.
abstract final class StartMatchFlowStep {
  static const labels = [
    'Teams',
    'Setup',
    'Squads',
    'Roles',
    'Officials',
    'Toss',
  ];

  static const teams = 0;
  static const setup = 1;
  static const squads = 2;
  static const roles = 3;
  static const officials = 4;
  static const toss = 5;
}

/// Loads teams and setup from Firestore into the start-match draft.
Future<void> hydrateStartMatchDraftFromMatch(
  WidgetRef ref,
  MatchModel match,
) async {
  final teamRepo = ref.read(teamRepositoryProvider);
  final teamA = match.teamAId != null
      ? await teamRepo.getTeam(match.teamAId!)
      : null;
  final teamB = match.teamBId != null
      ? await teamRepo.getTeam(match.teamBId!)
      : null;
  ref.read(startMatchDraftProvider.notifier).loadFromMatch(
        match: match,
        teamA: teamA,
        teamB: teamB,
      );

  final tournamentId = match.tournamentId;
  if (tournamentId != null && tournamentId.isNotEmpty) {
    final assignService = TournamentOfficialAssignService();
    final draft = ref.read(startMatchDraftProvider);
    if (assignService.shouldAutoFill(draft.setup)) {
      final officials = await ref
          .read(tournamentOfficialRepositoryProvider)
          .getActiveOfficials(tournamentId);
      if (officials.isNotEmpty) {
        final updated =
            assignService.applyTournamentOfficials(draft.setup, officials);
        ref.read(startMatchDraftProvider.notifier).applyTournamentOfficialsAutoFill(
              updated,
              autoFilled: true,
            );
        try {
          await persistMatchSetupDraft(ref);
        } catch (_) {
          // Non-blocking — user can still edit on officials screen.
        }
      }
    }
  }
}

/// Writes wizard progress back to the scheduled match document.
Future<void> persistMatchSetupDraft(WidgetRef ref) async {
  final draft = ref.read(startMatchDraftProvider);
  if (!draft.isExistingMatch) return;

  await ref.read(matchRepositoryProvider).syncMatchSetupFromDraft(
        matchId: draft.matchId,
        rules: draft.rules,
        location: draft.location,
        venue: draft.venue,
        scheduledAt: draft.scheduledAt,
        teamAName: draft.resolvedTeamAName,
        teamBName: draft.resolvedTeamBName,
        teamAId: draft.teamA?.id,
        teamBId: draft.teamB?.id,
        setup: draft.setup,
      );
}

bool _isTossStepComplete(MatchSetupData setup) {
  return setup.tossReady &&
      setup.coinResult != null &&
      setup.coinResult!.isNotEmpty;
}

List<InningsModel> inningsAfterToss(
  MatchModel? existing,
  InningsModel firstInnings,
) {
  if (existing == null || existing.innings.isEmpty) return [firstInnings];
  final hasScoring = existing.innings.any(
    (i) =>
        i.legalBalls > 0 ||
        i.status == InningsStatus.inProgress ||
        i.status == InningsStatus.completed,
  );
  if (hasScoring) return existing.innings;
  return [firstInnings];
}

InningsModel _firstInningsAfterToss(StartMatchDraft draft, MatchSetupData setup) {
  final tossSetupMatch = MatchModel(
    id: draft.matchId,
    title: '${draft.resolvedTeamAName} vs ${draft.resolvedTeamBName}',
    teamAId: draft.teamA?.id,
    teamBId: draft.teamB?.id,
    teamAName: draft.resolvedTeamAName,
    teamBName: draft.resolvedTeamBName,
    setup: setup,
  );
  final teams = TossTeamPolicy.firstInningsTeams(tossSetupMatch);
  return InningsModel(
    inningsNumber: 1,
    battingTeamId: teams.battingTeamId,
    bowlingTeamId: teams.bowlingTeamId,
    status: InningsStatus.notStarted,
  );
}

MatchModel buildMatchAfterToss({
  required StartMatchDraft draft,
  required MatchSetupData setup,
  required MatchModel? existing,
  String? createdBy,
}) {
  final city = draft.location.city.trim();
  final ground = draft.venue.trim();
  final scorerIds = setup.scorers
      .map((s) => s.userId)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toList();
  final firstInnings = _firstInningsAfterToss(draft, setup);
  final baseMatch = existing ??
      MatchModel(
        id: draft.matchId,
        title: '${draft.resolvedTeamAName} vs ${draft.resolvedTeamBName}',
        matchType: MatchType.single,
        teamAId: draft.teamA?.id,
        teamBId: draft.teamB?.id,
        teamAName: draft.resolvedTeamAName,
        teamBName: draft.resolvedTeamBName,
        rules: draft.rules,
        location: draft.location.copyWith(city: city),
        venue: ground,
        scheduledAt: draft.scheduledAt ?? DateTime.now(),
        createdBy: createdBy,
        scorerIds: scorerIds,
        setup: setup,
      );
  return baseMatch.copyWith(
    title: '${draft.resolvedTeamAName} vs ${draft.resolvedTeamBName}',
    status: MatchStatus.tossCompleted,
    teamAId: draft.teamA?.id,
    teamBId: draft.teamB?.id,
    teamAName: draft.resolvedTeamAName,
    teamBName: draft.resolvedTeamBName,
    rules: draft.rules,
    location: draft.location.copyWith(city: city),
    venue: ground,
    setup: setup,
    innings: inningsAfterToss(existing, firstInnings),
    currentInningsIndex: 0,
  );
}

Future<void> _ensureDefaultScorerOnDraft(WidgetRef ref) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) return;
  final profile = ref.read(currentUserProfileProvider).valueOrNull;
  final player =
      await ref.read(playerRepositoryProvider).getPlayerByUserId(uid);
  await ref.read(startMatchDraftProvider.notifier).ensureDefaultScorer1(
        userId: uid,
        name: profile?.displayName ??
            profile?.name ??
            player?.name ??
            'Scorer',
        photoUrl: profile?.photoUrl ?? player?.photoUrl,
        playerId: player?.playerId,
        playerDocId: player?.id,
      );
}

/// Commits toss result + first innings to Firestore.
Future<void> commitTossToFirestore(WidgetRef ref) async {
  final draft = ref.read(startMatchDraftProvider);
  if (!_isTossStepComplete(draft.setup)) return;

  await _ensureDefaultScorerOnDraft(ref);

  final updated = ref.read(startMatchDraftProvider);
  final setup = updated.setup.withViceCaptainsFromTeams(
    teamAViceCaptainId: updated.teamA?.viceCaptainId,
    teamBViceCaptainId: updated.teamB?.viceCaptainId,
  );
  final uid = ref.read(authStateProvider).value?.uid;
  final repo = ref.read(matchRepositoryProvider);
  final existing = await repo.getMatch(updated.matchId);
  final matchToSave = buildMatchAfterToss(
    draft: updated,
    setup: setup,
    existing: existing,
    createdBy: uid,
  );
  if (existing != null) {
    await repo.updateMatch(matchToSave);
  } else {
    await repo.createMatch(matchToSave);
  }
}

/// Saves toss wizard data to Firestore when the scorer is online.
/// Offline scorers keep progress in the draft until "Let's play".
Future<void> persistTossSetupWhenOnline(WidgetRef ref) async {
  if (!ref.read(connectivityServiceProvider).isOnline) return;
  await commitTossToFirestore(ref);
}

bool _hasWizardProgress(MatchSetupData setup) {
  return setup.hasTeamASquad ||
      setup.hasTeamBSquad ||
      setup.teamARolesReady ||
      setup.teamBRolesReady ||
      setup.umpires.isNotEmpty ||
      setup.scorers.length > 1 ||
      setup.commentators.isNotEmpty ||
      setup.referee != null ||
      setup.liveStreamers.isNotEmpty ||
      setup.tossReady;
}

/// Whether a wizard step has been completed (eligible for step-bar navigation).
bool isStartMatchStepComplete(int step, StartMatchDraft draft) {
  final setup = draft.setup;
  switch (step) {
    case StartMatchFlowStep.teams:
      return draft.hasBothTeams;
    case StartMatchFlowStep.setup:
      return draft.canProceedToSquad;
    case StartMatchFlowStep.squads:
      return setup.hasTeamASquad && setup.hasTeamBSquad;
    case StartMatchFlowStep.roles:
      return setup.rolesReady;
    case StartMatchFlowStep.officials:
      return setup.rolesReady ||
          setup.umpires.isNotEmpty ||
          setup.commentators.isNotEmpty ||
          setup.referee != null ||
          setup.liveStreamers.isNotEmpty ||
          setup.scorers.length > 1;
    case StartMatchFlowStep.toss:
      return setup.tossReady;
    default:
      return false;
  }
}

/// Route for a wizard step (used when tapping a completed step chip).
String startMatchStepRoute(int step, StartMatchDraft draft) {
  final setup = draft.setup;
  final idParam =
      draft.isExistingMatch ? 'matchId=${draft.matchId}&' : '';

  switch (step) {
    case StartMatchFlowStep.teams:
      return draft.isExistingMatch
          ? '/match/create?${idParam}step=teams'
          : '/match/create';
    case StartMatchFlowStep.setup:
      return draft.isExistingMatch
          ? '/match/create?${idParam}step=setup'
          : '/match/create?step=setup';
    case StartMatchFlowStep.squads:
      if (!setup.hasTeamASquad || !setup.hasTeamBSquad) {
        return '/match/create/squad/${setup.hasTeamASquad ? 'b' : 'a'}';
      }
      return '/match/create/squad/a';
    case StartMatchFlowStep.roles:
      if (!setup.teamARolesReady) return '/match/create/roles/a';
      return '/match/create/roles/b';
    case StartMatchFlowStep.officials:
      return '/match/create/officials?wizard=1';
    case StartMatchFlowStep.toss:
      return '/match/create/toss';
    default:
      return '/match/create';
  }
}

/// Navigates to a completed wizard step, replacing the current route stack.
void navigateToStartMatchStep(
  BuildContext context,
  int step,
  StartMatchDraft draft,
) {
  context.go(startMatchStepRoute(step, draft));
}

/// First incomplete wizard route for a scheduled match.
String resolveMatchSetupRoute(
  MatchModel match, {
  bool forceSetupStep = false,
}) {
  final setup = match.setup ?? const MatchSetupData();
  final playersPerTeam = match.rules.playersPerTeam;

  if (match.status == MatchStatus.tossCompleted) {
    return '/match/${match.id}/start-innings';
  }

  if (forceSetupStep && MatchLifecycle.isUpcoming(match)) {
    return '/match/create?matchId=${match.id}&step=setup';
  }

  if (setup.tossReady) {
    return '/match/create/toss';
  }

  if (setup.playingSquadsReady(playersPerTeam) && setup.rolesReady) {
    return '/match/create/toss';
  }

  if (setup.hasTeamBSquad && !setup.teamBRolesReady) {
    return '/match/create/roles/b';
  }

  if (setup.hasTeamASquad && !setup.hasTeamBSquad) {
    return '/match/create/squad/b';
  }

  if (setup.hasTeamASquad && !setup.teamARolesReady) {
    return '/match/create/roles/a';
  }

  if (!setup.hasTeamASquad && _hasWizardProgress(setup)) {
    return '/match/create/squad/a';
  }

  return '/match/create?matchId=${match.id}&step=setup';
}

/// Opens the match setup wizard for scorers (never auto-starts live scoring).
Future<void> openMatchSetupFlow(
  BuildContext context, {
  required WidgetRef ref,
  required MatchModel match,
  bool forceSetupStep = false,
}) async {
  if (match.status == MatchStatus.tossCompleted) {
    if (context.mounted) {
      context.push('/match/${match.id}/start-innings');
    }
    return;
  }

  if (match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak) {
    if (context.mounted) {
      context.push('/match/${match.id}/score');
    }
    return;
  }

  if (!MatchLifecycle.isUpcoming(match)) {
    if (context.mounted) {
      context.push('/match/${match.id}');
    }
    return;
  }

  try {
    await hydrateStartMatchDraftFromMatch(ref, match);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load match setup: $e')),
      );
    }
    return;
  }

  if (!context.mounted) return;
  context.push(resolveMatchSetupRoute(match, forceSetupStep: forceSetupStep));
}

/// Returns to the tournament dashboard from the start-match wizard.
Future<void> confirmExitToTournamentDashboard(
  BuildContext context,
  WidgetRef ref, {
  String? tournamentId,
}) async {
  final tid = (tournamentId ?? ref.read(startMatchDraftProvider).tournamentId)
      ?.trim();
  if (tid == null || tid.isEmpty) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/matches');
    }
    return;
  }

  final leave = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Leave match setup?'),
      content: const Text(
        'Your progress is saved on this match. You can continue setup later from the tournament.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Back to tournament'),
        ),
      ],
    ),
  );
  if (leave == true && context.mounted) {
    context.go('/tournaments/$tid');
  }
}

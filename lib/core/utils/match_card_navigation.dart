import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../domain/scoring/match_lifecycle.dart';
import '../../shared/providers/providers.dart';
import '../../shared/providers/tournament_providers.dart';
import '../../shared/providers/tournament_match_scoring_providers.dart';
import 'match_setup_navigation.dart';

/// Opens the match hub, or prompts assigned scorers on live/upcoming matches.
Future<void> openMatchFromListCard(
  BuildContext context, {
  required WidgetRef ref,
  required MatchModel match,
  required String? userId,
}) async {
  final isLive = MatchLifecycle.isEffectivelyLive(match);
  final isUpcoming = MatchLifecycle.isUpcoming(match);
  final role =
      ref.read(currentUserProfileProvider).valueOrNull?.role ?? UserRole.organizer;
  final access = resolveTournamentMatchScoringAccess(
    match: match,
    userId: userId,
    role: role,
    tournament: match.tournamentId != null && match.tournamentId!.isNotEmpty
        ? ref.read(tournamentProvider(match.tournamentId!)).valueOrNull
        : null,
    officials: match.tournamentId != null && match.tournamentId!.isNotEmpty
        ? ref.read(tournamentOfficialsProvider(match.tournamentId!)).valueOrNull ??
            []
        : const [],
  );

  if ((isLive || isUpcoming) && access.canStartSetup) {
    final choice = await _showScorerMatchChoiceSheet(
      context,
      isUpcoming: isUpcoming,
    );
    if (!context.mounted || choice == null) return;

    if (choice == 'score') {
      await openMatchScoring(
        context,
        ref: ref,
        match: match,
        userId: userId,
        forceSetupStep: access.forceSetupStep,
      );
      return;
    }
  }

  if (context.mounted) {
    context.push('/match/${match.id}');
  }
}

Future<String?> _showScorerMatchChoiceSheet(
  BuildContext context, {
  required bool isUpcoming,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Spectate'),
            subtitle: const Text('Browse match info, squads, and details'),
            onTap: () => Navigator.pop(ctx, 'spectate'),
          ),
          ListTile(
            leading: const Icon(Icons.scoreboard_outlined),
            title: const Text('Live Score'),
            subtitle: Text(
              isUpcoming
                  ? 'Continue match setup before going live'
                  : 'Open the scoring screen',
            ),
            onTap: () => Navigator.pop(ctx, 'score'),
          ),
        ],
      ),
    ),
  );
}

/// Routes scorers into setup wizard, start-innings, or live scoring.
Future<void> openMatchScoring(
  BuildContext context, {
  required WidgetRef ref,
  required MatchModel match,
  String? userId,
  bool forceSetupStep = false,
}) async {
  if (MatchLifecycle.isUpcoming(match)) {
    await openMatchSetupFlow(
      context,
      ref: ref,
      match: match,
      forceSetupStep: forceSetupStep,
    );
    return;
  }

  if (MatchLifecycle.canOpenScoringScreen(match)) {
    if (MatchLifecycle.hasScoringStarted(match) &&
        match.status == MatchStatus.tossCompleted) {
      try {
        await ref
            .read(matchRepositoryProvider)
            .repairLiveStatusIfScoringStarted(match.id);
      } catch (_) {
        // Non-blocking — scoring screen still opens from innings progress.
      }
    }
    if (context.mounted) {
      context.push('/match/${match.id}/score');
    }
    return;
  }

  if (MatchLifecycle.needsStartInnings(match)) {
    if (context.mounted) {
      context.push('/match/${match.id}/start-innings');
    }
    return;
  }

  if (context.mounted) {
    context.push('/match/${match.id}/score');
  }
}

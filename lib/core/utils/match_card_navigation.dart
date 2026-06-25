import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../domain/scoring/match_lifecycle.dart';
import '../../shared/providers/providers.dart';
import 'match_permissions.dart';
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
  final canManage = canManageMatch(
    match: match,
    userId: userId,
    role: role,
  );

  if ((isLive || isUpcoming) && canManage) {
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
}) async {
  if (MatchLifecycle.isUpcoming(match)) {
    await openMatchSetupFlow(context, ref: ref, match: match);
    return;
  }

  if (match.status == MatchStatus.tossCompleted) {
    if (context.mounted) {
      context.push('/match/${match.id}/start-innings');
    }
    return;
  }

  if (context.mounted) {
    context.push('/match/${match.id}/score');
  }
}

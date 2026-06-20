import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/enums.dart';
import '../../data/models/match_model.dart';
import 'match_scorer_utils.dart';

/// Opens the match hub, or prompts assigned scorers on live matches.
Future<void> openMatchFromListCard(
  BuildContext context, {
  required MatchModel match,
  required String? userId,
}) async {
  final isLive = match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;

  if (isLive && isPrimaryMatchScorer(match: match, userId: userId)) {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Spectate'),
              subtitle: const Text('Browse summary, scorecard, and comms'),
              onTap: () => Navigator.pop(ctx, 'spectate'),
            ),
            ListTile(
              leading: const Icon(Icons.scoreboard_outlined),
              title: const Text('Live Score'),
              subtitle: const Text('Open the scoring screen'),
              onTap: () => Navigator.pop(ctx, 'score'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || choice == null) return;

    if (choice == 'score') {
      context.push('/match/${match.id}/score');
      return;
    }
  }

  context.push('/match/${match.id}');
}

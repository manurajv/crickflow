import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/tournament_tab_shell.dart';

class TournamentLeaderboardTab extends ConsumerWidget {
  const TournamentLeaderboardTab({super.key, required this.tournamentId});

  final String tournamentId;

  static const _plannedSections = [
    'Top performers',
    'Batting leaders',
    'Bowling leaders',
    'MVP rankings',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TournamentTabShell(
      tournamentId: tournamentId,
      title: 'Leaderboard',
      subtitle: 'Top performers, batting and bowling leaders, and MVP rankings.',
      emptyMessage: 'Leaderboard data will appear here once matches are scored.',
      plannedSections: _plannedSections,
    );
  }
}

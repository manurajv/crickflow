import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/tournament_tab_shell.dart';

class TournamentHeroesTab extends ConsumerWidget {
  const TournamentHeroesTab({super.key, required this.tournamentId});

  final String tournamentId;

  static const _plannedSections = [
    'Tournament heroes',
    'Player spotlights',
    'MVPs',
    'Featured performers',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TournamentTabShell(
      tournamentId: tournamentId,
      title: 'Heroes',
      subtitle:
          'Celebrate tournament heroes, spotlights, MVPs, and featured performers.',
      emptyMessage: 'Heroes and spotlights will appear here during the tournament.',
      plannedSections: _plannedSections,
    );
  }
}

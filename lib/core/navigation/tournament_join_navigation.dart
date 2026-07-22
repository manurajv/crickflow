import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/my_cricket_ui_provider.dart';

/// My Cricket tab index for Tournaments.
const myCricketTournamentsTabIndex = 1;

void goToMyCricketTournamentsTab(WidgetRef ref, BuildContext context) {
  ref.read(myCricketInitialTabProvider.notifier).state =
      myCricketTournamentsTabIndex;
  // Prefer go over pop — clears tournament routes after delete/leave.
  // Include ?tab= so My Cricket applies Tournaments even on a cold open.
  context.go('/matches?tab=$myCricketTournamentsTabIndex');
}

bool isTournamentJoinPath(String path) {
  return RegExp(r'^/tournaments/[^/]+/join').hasMatch(path);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/my_cricket_ui_provider.dart';

/// My Cricket tab index for Tournaments.
const myCricketTournamentsTabIndex = 1;

void goToMyCricketTournamentsTab(WidgetRef ref, BuildContext context) {
  ref.read(myCricketInitialTabProvider.notifier).state =
      myCricketTournamentsTabIndex;
  context.go('/matches');
}

bool isTournamentJoinPath(String path) {
  return RegExp(r'^/tournaments/[^/]+/join').hasMatch(path);
}

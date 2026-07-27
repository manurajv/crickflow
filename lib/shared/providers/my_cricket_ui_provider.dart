import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/my_cricket/my_cricket_filters.dart';

/// Shared search text for My Cricket tabs (matches, teams, tournaments).
final myCricketSearchProvider = StateProvider<String>((ref) => '');

/// Jump to tab index when opening `/matches` (-1=none, 0=Matches … 4=Highlights).
final myCricketInitialTabProvider = StateProvider<int>((ref) => -1);

/// Apply Matches tab scope once when opening from Home (cleared after apply).
final myCricketMatchesInitialScopeProvider =
    StateProvider<MyCricketListScope?>((ref) => null);

/// Apply Tournaments tab scope once when opening from Home (cleared after apply).
final myCricketTournamentsInitialScopeProvider =
    StateProvider<MyCricketListScope?>((ref) => null);
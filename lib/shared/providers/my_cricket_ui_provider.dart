import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared search text for My Cricket tabs (matches, teams, tournaments).
final myCricketSearchProvider = StateProvider<String>((ref) => '');

/// Jump to tab index when opening `/matches` (0=Matches … 3=Stats, 4=Highlights).
final myCricketInitialTabProvider = StateProvider<int>((ref) => 0);

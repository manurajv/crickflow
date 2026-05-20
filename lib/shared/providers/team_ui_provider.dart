import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 0 = Your teams, 1 = Opponents, 2 = Add (create team).
final teamsInitialTabProvider = StateProvider<int>((ref) => 0);

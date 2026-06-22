import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../domain/wagon_wheel/wagon_wheel_filter_options.dart';
import 'providers.dart';

/// Scope for loading filter dropdown options.
class WagonWheelOptionsScope {
  const WagonWheelOptionsScope({
    this.matchId,
    this.tournamentId,
    this.batterId,
    this.teamId,
    this.batterCareerMode = false,
  });

  final String? matchId;
  final String? tournamentId;
  final String? batterId;
  final String? teamId;

  /// Batter career analytics — bowlers faced, opponent teams, no innings.
  final bool batterCareerMode;

  @override
  bool operator ==(Object other) =>
      other is WagonWheelOptionsScope &&
      matchId == other.matchId &&
      tournamentId == other.tournamentId &&
      batterId == other.batterId &&
      teamId == other.teamId &&
      batterCareerMode == other.batterCareerMode;

  @override
  int get hashCode =>
      Object.hash(matchId, tournamentId, batterId, teamId, batterCareerMode);
}

final wagonWheelFilterOptionsServiceProvider =
    Provider((ref) => WagonWheelFilterOptionsService());

final wagonWheelFilterOptionsProvider = Provider.family<
    WagonWheelFilterOptions, WagonWheelOptionsScope>((ref, scope) {
  final service = ref.watch(wagonWheelFilterOptionsServiceProvider);
  final allMatches = ref.watch(matchesProvider).valueOrNull ?? [];

  final matches = _scopedMatches(allMatches, scope);
  final events = <BallEventModel>[];

  for (final match in matches) {
    final ev = ref.watch(ballEventsProvider(match.id)).valueOrNull ?? [];
    events.addAll(ev);
  }

  return service.build(
    matches: matches,
    events: events,
    batterCareerMode: scope.batterCareerMode,
    batterId: scope.batterId,
  );
});

List<MatchModel> _scopedMatches(
  List<MatchModel> all,
  WagonWheelOptionsScope scope,
) {
  if (scope.matchId != null) {
    return all.where((m) => m.id == scope.matchId).toList();
  }
  if (scope.tournamentId != null) {
    return all.where((m) => m.tournamentId == scope.tournamentId).toList();
  }
  if (scope.batterCareerMode && scope.batterId != null) {
    return all
        .where((m) => WagonWheelFilterOptionsService.matchHasBatter(
              m,
              scope.batterId!,
            ))
        .toList();
  }
  if (scope.batterId != null || scope.teamId != null) {
    return all;
  }
  return all;
}

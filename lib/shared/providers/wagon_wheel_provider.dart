import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import '../../domain/wagon_wheel/wagon_wheel_batting_orientation.dart';
import '../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../domain/wagon_wheel/wagon_wheel_filter_options.dart';
import 'providers.dart';

final wagonWheelAnalyticsServiceProvider =
    Provider((ref) => WagonWheelAnalyticsService());

/// Player batting style for enriching handedness lookup on batter-filtered views.
final wagonWheelPlayerBattingStyleProvider =
    FutureProvider.family<String?, String>((ref, playerId) async {
  final player = await ref.read(playerRepositoryProvider).getPlayer(playerId);
  return player?.battingStyle;
});

class WagonWheelAnalyticsData {
  const WagonWheelAnalyticsData({
    this.shots = const [],
    this.insights = const WagonWheelInsights(),
    this.leftHandedByBatterId = const {},
  });

  final List<WagonWheelShotPoint> shots;
  final WagonWheelInsights insights;
  final Map<String, bool> leftHandedByBatterId;
}

final wagonWheelAnalyticsProvider = Provider.family<
    WagonWheelAnalyticsData, WagonWheelFilter>((ref, filter) {
  final service = ref.watch(wagonWheelAnalyticsServiceProvider);
  final matches = ref.watch(matchesProvider).valueOrNull ?? [];

  final scopedMatches = _scopedMatches(matches, filter);
  final events = <BallEventModel>[];

  for (final match in scopedMatches) {
    final ev = ref.watch(ballEventsProvider(match.id)).valueOrNull ?? [];
    events.addAll(ev);
  }

  final shots = service.extractShots(
    events: events,
    matches: scopedMatches,
    filter: filter,
  );

  var leftHandedLookup =
      WagonWheelBattingOrientation.leftHandedLookupFromMatches(scopedMatches);

  if (filter.batterId != null) {
    final profileStyle =
        ref.watch(wagonWheelPlayerBattingStyleProvider(filter.batterId!)).valueOrNull;
    leftHandedLookup = WagonWheelBattingOrientation.enrichLeftHandedLookup(
      leftHandedLookup,
      batterId: filter.batterId,
      battingStyle: profileStyle,
    );
  }

  final insights = service.buildInsights(
    shots,
    leftHandedLookup: leftHandedLookup,
    fallbackBatterId: filter.batterId,
  );

  return WagonWheelAnalyticsData(
    shots: shots,
    insights: insights,
    leftHandedByBatterId: leftHandedLookup,
  );
});

List<MatchModel> _scopedMatches(
  List<MatchModel> matches,
  WagonWheelFilter filter,
) {
  if (filter.matchId != null) {
    return matches.where((m) => m.id == filter.matchId).toList();
  }
  if (filter.tournamentId != null) {
    return matches
        .where((m) => m.tournamentId == filter.tournamentId)
        .toList();
  }
  if (filter.batterCareerMode && filter.batterId != null) {
    return matches
        .where(
          (m) => WagonWheelFilterOptionsService.matchHasBatter(
            m,
            filter.batterId!,
          ),
        )
        .toList();
  }
  return matches;
}

/// Match-scoped wagon wheel (Insights tab).
final matchWagonWheelProvider =
    Provider.family<WagonWheelAnalyticsData, String>((ref, matchId) {
  return ref.watch(
    wagonWheelAnalyticsProvider(WagonWheelFilter(matchId: matchId)),
  );
});

/// Batter career wagon wheel across loaded matches.
final batterWagonWheelProvider =
    Provider.family<WagonWheelAnalyticsData, String>((ref, batterId) {
  return ref.watch(
    wagonWheelAnalyticsProvider(WagonWheelFilter(batterId: batterId)),
  );
});

/// Bowler wagon wheel — runs conceded with direction.
final bowlerWagonWheelProvider =
    Provider.family<WagonWheelAnalyticsData, String>((ref, bowlerId) {
  return ref.watch(
    wagonWheelAnalyticsProvider(WagonWheelFilter(bowlerId: bowlerId)),
  );
});

/// Team wagon wheel.
final teamWagonWheelProvider =
    Provider.family<WagonWheelAnalyticsData, String>((ref, teamId) {
  return ref.watch(
    wagonWheelAnalyticsProvider(WagonWheelFilter(teamId: teamId)),
  );
});

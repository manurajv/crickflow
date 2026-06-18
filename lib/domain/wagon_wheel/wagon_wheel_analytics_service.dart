import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/wagon_wheel_data.dart';
import 'wagon_wheel_batting_orientation.dart';
import 'wagon_wheel_filter.dart';

class WagonWheelShotPoint {
  const WagonWheelShotPoint({
    required this.event,
    required this.wagonWheel,
    required this.batsmanRuns,
    required this.batterId,
    required this.bowlerId,
    required this.battingTeamId,
    required this.matchId,
    required this.inningsNumber,
    required this.timestamp,
  });

  final BallEventModel event;
  final WagonWheelData wagonWheel;
  final int batsmanRuns;
  final String? batterId;
  final String? bowlerId;
  final String? battingTeamId;
  final String matchId;
  final int inningsNumber;
  final DateTime? timestamp;
}

class WagonWheelInsights {
  const WagonWheelInsights({
    this.totalShots = 0,
    this.boundaryCount = 0,
    this.offSidePercent = 0,
    this.legSidePercent = 0,
    this.straightPercent = 0,
    this.boundaryPercent = 0,
    this.favoriteZone = '',
    this.mostCommonBoundaryRegion = '',
    this.strongZones = const [],
    this.weakZones = const [],
    this.concededHotspots = const [],
  });

  final int totalShots;
  final int boundaryCount;
  final double offSidePercent;
  final double legSidePercent;
  final double straightPercent;
  final double boundaryPercent;
  final String favoriteZone;
  final String mostCommonBoundaryRegion;
  final List<String> strongZones;
  final List<String> weakZones;
  final List<String> concededHotspots;
}

class WagonWheelAnalyticsService {
  List<WagonWheelShotPoint> extractShots({
    required List<BallEventModel> events,
    required List<MatchModel> matches,
    required WagonWheelFilter filter,
  }) {
    final matchById = {for (final m in matches) m.id: m};
    final points = <WagonWheelShotPoint>[];

    for (final event in events) {
      final ww = _wagonWheelFromEvent(event);
      if (ww == null || !ww.enabled) continue;

      final match = matchById[event.matchId];
      if (match == null) continue;

      if (filter.matchId != null && event.matchId != filter.matchId) continue;
      if (filter.tournamentId != null &&
          match.tournamentId != filter.tournamentId) {
        continue;
      }
      if (filter.inningsNumber != null &&
          event.inningsNumber != filter.inningsNumber) {
        continue;
      }
      if (filter.batterId != null && event.strikerId != filter.batterId) {
        continue;
      }
      if (filter.bowlerId != null && event.bowlerId != filter.bowlerId) {
        continue;
      }

      final inn = _inningsForEvent(match, event.inningsNumber);
      final battingTeamId = inn?.battingTeamId;
      if (filter.teamId != null && battingTeamId != filter.teamId) continue;

      final ts = event.timestamp;
      if (filter.fromDate != null &&
          ts != null &&
          ts.isBefore(filter.fromDate!)) {
        continue;
      }
      if (filter.toDate != null && ts != null && ts.isAfter(filter.toDate!)) {
        continue;
      }

      final batsmanRuns = _batsmanRuns(event);
      if (!filter.runFilter.matches(batsmanRuns)) continue;

      points.add(
        WagonWheelShotPoint(
          event: event,
          wagonWheel: ww,
          batsmanRuns: batsmanRuns,
          batterId: event.strikerId,
          bowlerId: event.bowlerId,
          battingTeamId: battingTeamId,
          matchId: event.matchId,
          inningsNumber: event.inningsNumber,
          timestamp: ts,
        ),
      );
    }

    return points;
  }

  /// All wagon wheel analytics use handedness-adjusted coordinates.
  WagonWheelInsights buildInsights(
    List<WagonWheelShotPoint> shots, {
    Map<String, bool> leftHandedLookup = const {},
    String? fallbackBatterId,
    String? fallbackBattingStyle,
  }) {
    if (shots.isEmpty) return const WagonWheelInsights();

    var offSide = 0;
    var legSide = 0;
    var straight = 0;
    var boundaries = 0;
    final zoneCounts = <String, int>{};

    for (final shot in shots) {
      final coords = WagonWheelBattingOrientation.getAnalyticsCoordinates(
        shot,
        leftHandedLookup,
        fallbackBatterId: fallbackBatterId,
        fallbackBattingStyle: fallbackBattingStyle,
      );

      if (coords.dx < 40) {
        offSide++;
      } else if (coords.dx > 60) {
        legSide++;
      } else {
        straight++;
      }

      if (shot.batsmanRuns == 4 || shot.batsmanRuns == 6) {
        boundaries++;
      }

      final zone = WagonWheelBattingOrientation.zoneLabel(coords.dx, coords.dy);
      zoneCounts[zone] = (zoneCounts[zone] ?? 0) + 1;
    }

    final total = shots.length;
    final sortedZones = zoneCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final favorite = sortedZones.isNotEmpty ? sortedZones.first.key : '';

    final boundaryShots = shots
        .where((s) => s.batsmanRuns == 4 || s.batsmanRuns == 6)
        .toList();
    final boundaryZones = <String, int>{};
    for (final s in boundaryShots) {
      final coords = WagonWheelBattingOrientation.getAnalyticsCoordinates(
        s,
        leftHandedLookup,
        fallbackBatterId: fallbackBatterId,
        fallbackBattingStyle: fallbackBattingStyle,
      );
      final z = WagonWheelBattingOrientation.zoneLabel(coords.dx, coords.dy);
      boundaryZones[z] = (boundaryZones[z] ?? 0) + 1;
    }
    final topBoundaryZone = boundaryZones.entries.isEmpty
        ? ''
        : (boundaryZones.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    final avg = total == 0 ? 0.0 : total / zoneCounts.length;
    final strong = sortedZones
        .where((e) => e.value > avg)
        .map((e) => e.key)
        .take(3)
        .toList();
    final weak = sortedZones.reversed
        .where((e) => e.value < avg * 0.5)
        .map((e) => e.key)
        .take(3)
        .toList();

    return WagonWheelInsights(
      totalShots: total,
      boundaryCount: boundaries,
      offSidePercent: total == 0 ? 0 : (offSide / total) * 100,
      legSidePercent: total == 0 ? 0 : (legSide / total) * 100,
      straightPercent: total == 0 ? 0 : (straight / total) * 100,
      boundaryPercent: total == 0 ? 0 : (boundaries / total) * 100,
      favoriteZone: favorite,
      mostCommonBoundaryRegion: topBoundaryZone,
      strongZones: strong,
      weakZones: weak,
      concededHotspots: strong,
    );
  }

  WagonWheelData? _wagonWheelFromEvent(BallEventModel event) {
    return event.wagonWheel;
  }

  InningsModel? _inningsForEvent(MatchModel match, int inningsNumber) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == inningsNumber) return inn;
    }
    return null;
  }

  int _batsmanRuns(BallEventModel event) {
    if (event.eventType == BallEventType.noBall) {
      return event.batsmanRuns;
    }
    return event.batsmanRuns;
  }
}

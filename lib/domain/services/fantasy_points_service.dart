import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/fantasy_entry_model.dart';
import '../../data/models/fantasy_league_model.dart';

/// Dream11-style points from ball events (MVP rules).
class FantasyPointsService {
  const FantasyPointsService();

  static const int wicketPoints = 25;
  static const int catchPoints = 8;
  static const int fourBonus = 1;
  static const int sixBonus = 2;

  /// Per-player raw points before captain / vice multipliers.
  Map<String, double> rawPlayerPoints(List<BallEventModel> events) {
    final points = <String, double>{};

    void add(String? playerId, double value) {
      if (playerId == null || playerId.isEmpty || value == 0) return;
      points[playerId] = (points[playerId] ?? 0) + value;
    }

    for (final e in events) {
      if (e.strikerId != null && e.batsmanRuns > 0) {
        add(e.strikerId, e.batsmanRuns.toDouble());
        if (e.batsmanRuns == 4) add(e.strikerId, fourBonus.toDouble());
        if (e.batsmanRuns == 6) add(e.strikerId, sixBonus.toDouble());
      }

      final isWicket = e.wicketType != null ||
          e.eventType == BallEventType.wicket ||
          e.dismissedPlayerId != null;

      if (isWicket) {
        add(e.bowlerId, wicketPoints.toDouble());
        add(e.primaryFielderId ?? e.fielderId, catchPoints.toDouble());
      }
    }

    return points;
  }

  double totalForEntry({
    required FantasyEntryModel entry,
    required FantasyLeagueModel league,
    required List<BallEventModel> events,
  }) {
    if (entry.playerIds.isEmpty) return 0;

    final raw = rawPlayerPoints(events);
    final squad = entry.playerIds.toSet();
    var total = 0.0;

    for (final playerId in squad) {
      var pts = raw[playerId] ?? 0;
      if (playerId == entry.captainId) {
        pts *= league.captainMultiplier;
      } else if (playerId == entry.viceCaptainId) {
        pts *= league.viceCaptainMultiplier;
      }
      total += pts;
    }

    return double.parse(total.toStringAsFixed(1));
  }
}

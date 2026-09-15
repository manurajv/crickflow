import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/enums.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../data/models/match_model.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../domain/scoring/match_lifecycle.dart';

/// Persists which match the user was broadcasting so the app can reopen the studio.
class ActiveStreamSession {
  ActiveStreamSession._();

  static Future<void> setActive(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.activeLiveStreamMatchId, matchId);
  }

  static Future<String?> readMatchId() async {
    final prefs = await SharedPreferences.getInstance();
    final matchId = prefs.getString(PrefsKeys.activeLiveStreamMatchId);
    if (matchId == null || matchId.isEmpty) return null;
    return matchId;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.activeLiveStreamMatchId);
  }

  static bool isResumeEligible(MatchModel? match) {
    if (match == null ||
        match.status == MatchStatus.abandoned ||
        MatchLifecycle.isCompleted(match)) {
      return false;
    }
    return match.stream.status == StreamStatus.live;
  }

  /// Keeps only a genuinely active broadcast session and clears stale state.
  static Future<String?> validate(MatchRepository matchRepository) async {
    final matchId = await readMatchId();
    if (matchId == null) return null;

    try {
      final match = await matchRepository.getMatch(matchId);
      if (isResumeEligible(match)) {
        return matchId;
      }
    } catch (_) {}

    await clear();
    return null;
  }

  /// Returns `/match/:id/stream` when a saved session is still live on the server.
  static Future<String?> resolveResumeRoute(
    MatchRepository matchRepository,
  ) async {
    final matchId = await validate(matchRepository);
    return matchId == null ? null : '/match/$matchId/stream';
  }
}

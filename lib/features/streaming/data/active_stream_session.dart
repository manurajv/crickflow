import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/enums.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../data/repositories/match_repository.dart';

/// Persists which match the user was broadcasting so the app can reopen the studio.
class ActiveStreamSession {
  ActiveStreamSession._();

  static Future<void> setActive(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.activeLiveStreamMatchId, matchId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.activeLiveStreamMatchId);
  }

  /// Returns `/match/:id/stream` when a saved session is still live on the server.
  static Future<String?> resolveResumeRoute(MatchRepository matchRepository) async {
    final prefs = await SharedPreferences.getInstance();
    final matchId = prefs.getString(PrefsKeys.activeLiveStreamMatchId);
    if (matchId == null || matchId.isEmpty) return null;

    try {
      final match = await matchRepository.getMatch(matchId);
      if (match?.stream.status == StreamStatus.live) {
        return '/match/$matchId/stream';
      }
    } catch (_) {}

    await clear();
    return null;
  }
}

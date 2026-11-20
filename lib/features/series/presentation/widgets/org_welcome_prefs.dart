import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/prefs_keys.dart';

/// Persistence for the post-create / first-open org admin welcome tip.
///
/// Behaviour:
/// - Admins only (caller enforces).
/// - Shown at most once per org per user, unless [neverAsk] is set.
/// - [neverAsk] (Don't show again) suppresses the tip for every org for that user.
/// - After create we force a show attempt via `?welcome=1` (still respects neverAsk).
class OrgWelcomePrefs {
  OrgWelcomePrefs(this._prefs);

  final SharedPreferences _prefs;

  bool neverAsk(String uid) =>
      _prefs.getBool(PrefsKeys.orgWelcomeNeverAsk(uid)) ?? false;

  bool seenForOrg(String uid, String seriesId) =>
      _prefs.getBool(PrefsKeys.orgWelcomeSeen(uid, seriesId)) ?? false;

  /// Whether the tip should be presented for this admin + org.
  bool shouldShow({
    required String uid,
    required String seriesId,
    bool forceFromCreate = false,
  }) {
    if (uid.isEmpty || seriesId.isEmpty) return false;
    if (neverAsk(uid)) return false;
    if (forceFromCreate) return true;
    return !seenForOrg(uid, seriesId);
  }

  Future<void> markSeen(String uid, String seriesId) async {
    await _prefs.setBool(PrefsKeys.orgWelcomeSeen(uid, seriesId), true);
  }

  Future<void> setNeverAsk(String uid, {required bool value}) async {
    await _prefs.setBool(PrefsKeys.orgWelcomeNeverAsk(uid), value);
  }

  Future<void> dismiss({
    required String uid,
    required String seriesId,
    required bool neverAskAgain,
  }) async {
    await markSeen(uid, seriesId);
    if (neverAskAgain) {
      await setNeverAsk(uid, value: true);
    }
  }
}

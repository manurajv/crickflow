import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../data/models/location_filter_selection.dart';

/// Persisted Community feed location selections.
class CommunityLocationFilterStore {
  CommunityLocationFilterStore(this._prefs);

  final SharedPreferences _prefs;

  List<LocationFilterSelection> read() {
    final raw = _prefs.getString(PrefsKeys.communityLocationFilter);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map(
            (e) => LocationFilterSelection.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((e) => !e.isEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> write(List<LocationFilterSelection> selections) async {
    final encoded = jsonEncode(selections.map((e) => e.toMap()).toList());
    await _prefs.setString(PrefsKeys.communityLocationFilter, encoded);
  }

  Future<void> clear() async {
    await _prefs.remove(PrefsKeys.communityLocationFilter);
  }
}

class CommunityHiddenPostsStore {
  CommunityHiddenPostsStore(this._prefs);

  final SharedPreferences _prefs;

  Set<String> read() {
    final list = _prefs.getStringList(PrefsKeys.communityHiddenPosts) ?? const [];
    return list.toSet();
  }

  Future<void> hide(String postId) async {
    final set = read()..add(postId);
    await _prefs.setStringList(PrefsKeys.communityHiddenPosts, set.toList());
  }

  Future<void> unhide(String postId) async {
    final set = read()..remove(postId);
    await _prefs.setStringList(PrefsKeys.communityHiddenPosts, set.toList());
  }
}

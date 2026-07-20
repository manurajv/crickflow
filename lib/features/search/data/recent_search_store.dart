import 'package:shared_preferences/shared_preferences.dart';

/// Persists recent search queries locally (SharedPreferences).
class RecentSearchStore {
  RecentSearchStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'cf_recent_searches_v1';
  static const _max = 12;

  List<String> read() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw.where((e) => e.trim().isNotEmpty).toList();
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = read().where((e) => e.toLowerCase() != q.toLowerCase()).toList();
    list.insert(0, q);
    await _prefs.setStringList(_key, list.take(_max).toList());
  }

  Future<void> remove(String query) async {
    final list = read()
        .where((e) => e.toLowerCase() != query.trim().toLowerCase())
        .toList();
    await _prefs.setStringList(_key, list);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

/// Shared in-memory TTL cache for admin one-shot reads.
///
/// Use for settings, role usage counts, summary probes, and catalogs.
/// Not a substitute for Firestore offline persistence.
class AdminCache {
  AdminCache({this.defaultTtl = const Duration(minutes: 2)});

  final Duration defaultTtl;
  final Map<String, _AdminCacheEntry> _entries = {};

  static final AdminCache shared = AdminCache();

  T? get<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  void set<T>(String key, T value, {Duration? ttl}) {
    _entries[key] = _AdminCacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  Future<T> getOrLoad<T>(
    String key,
    Future<T> Function() load, {
    Duration? ttl,
    bool force = false,
  }) async {
    if (!force) {
      final hit = get<T>(key);
      if (hit != null) return hit;
    }
    final value = await load();
    set(key, value, ttl: ttl);
    return value;
  }

  void invalidate(String key) => _entries.remove(key);

  void invalidatePrefix(String prefix) {
    _entries.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clear() => _entries.clear();

  int get size => _entries.length;
}

class _AdminCacheEntry {
  _AdminCacheEntry({required this.value, required this.expiresAt});

  final Object? value;
  final DateTime expiresAt;
}

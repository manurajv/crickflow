import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/prefs_keys.dart';
import '../../../data/models/location_model.dart';

/// One selectable location node (country / state / district / city).
class CommunityLocationSelection {
  const CommunityLocationSelection({
    this.country = '',
    this.stateProvince = '',
    this.district = '',
    this.city = '',
  });

  final String country;
  final String stateProvince;
  final String district;
  final String city;

  bool get isEmpty =>
      country.isEmpty &&
      stateProvince.isEmpty &&
      district.isEmpty &&
      city.isEmpty;

  String get label {
    final parts = <String>[
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
        'country': country,
        'stateProvince': stateProvince,
        'district': district,
        'city': city,
      };

  factory CommunityLocationSelection.fromMap(Map<String, dynamic> map) {
    return CommunityLocationSelection(
      country: map['country'] as String? ?? '',
      stateProvince: map['stateProvince'] as String? ?? '',
      district: map['district'] as String? ?? '',
      city: map['city'] as String? ?? '',
    );
  }

  /// True when [loc] matches this selection (broader selections match more).
  bool matches(LocationModel loc) {
    if (isEmpty) return true;
    bool eq(String a, String b) =>
        a.trim().toLowerCase() == b.trim().toLowerCase();

    if (country.isNotEmpty && !eq(loc.country, country)) return false;
    if (stateProvince.isNotEmpty &&
        !eq(loc.stateProvince, stateProvince)) {
      return false;
    }
    if (district.isNotEmpty && !eq(loc.district, district)) return false;
    if (city.isNotEmpty && !eq(loc.city, city)) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is CommunityLocationSelection &&
      other.country == country &&
      other.stateProvince == stateProvince &&
      other.district == district &&
      other.city == city;

  @override
  int get hashCode => Object.hash(country, stateProvince, district, city);
}

class CommunityLocationFilterStore {
  CommunityLocationFilterStore(this._prefs);

  final SharedPreferences _prefs;

  List<CommunityLocationSelection> read() {
    final raw = _prefs.getString(PrefsKeys.communityLocationFilter);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map(
            (e) => CommunityLocationSelection.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((e) => !e.isEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> write(List<CommunityLocationSelection> selections) async {
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

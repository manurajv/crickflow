/// Google Places / Geocoding / Maps JavaScript API key.
///
/// Enable **Geocoding API**, **Places API**, and **Maps JavaScript API** in
/// Google Cloud Console, then **restrict** the key to Android package
/// `com.mavixas.crickflow` + your release SHA-1 (and iOS bundle id).
///
/// Prefer build-time injection:
/// `flutter build appbundle --release --dart-define=GOOGLE_MAPS_API_KEY=...`
/// See [docs/PLAY_STORE_LAUNCH.md].
class MapsConfig {
  MapsConfig._();

  /// Embedded fallback used when dart-define is omitted (dev convenience).
  /// Restrict this key in GCP before public launch — do not treat as a secret.
  static const String _embeddedKey = 'AIzaSyD8TQN5NYuQnrgLvnA_eys6ubSYJ7BtZZc';

  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: _embeddedKey,
  );

  static bool get isConfigured => apiKey.isNotEmpty;
}

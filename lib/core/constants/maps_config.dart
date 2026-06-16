/// Google Places / Geocoding API key for location search and reverse geocoding.
/// Enable **Geocoding API** and **Places API** in Google Cloud Console.
/// Override at build time: `--dart-define=GOOGLE_MAPS_API_KEY=your_key`
class MapsConfig {
  MapsConfig._();

  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyD8TQN5NYuQnrgLvnA_eys6ubSYJ7BtZZc',
  );
}

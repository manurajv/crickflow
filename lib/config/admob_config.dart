import 'package:flutter/foundation.dart';

/// AdMob unit IDs — test IDs in debug, production placeholders in release.
///
/// Replace [AdMobConfig.androidAppId] / [iosAppId] and production unit IDs
/// in `AndroidManifest.xml` / `Info.plist` and below before store release.
abstract final class AdMobConfig {
  /// Google sample app IDs (safe for development).
  static const androidTestAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const iosTestAppId = 'ca-app-pub-3940256099942544~1458002511';

  /// Production app IDs — set before release. Until then, test IDs are used.
  static const androidProdAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const iosProdAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const androidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const androidTestNative = 'ca-app-pub-3940256099942544/2247696110';
  static const iosTestNative = 'ca-app-pub-3940256099942544/3986624511';

  /// Production unit IDs — replace with real AdMob units before release.
  static const androidProdBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const iosProdBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const androidProdNative = 'ca-app-pub-3940256099942544/2247696110';
  static const iosProdNative = 'ca-app-pub-3940256099942544/3986624511';

  /// When true, always use Google test units (also forced in [kDebugMode]).
  static const forceTestAds = true;

  static bool get useTestAds => forceTestAds || kDebugMode;

  static String bannerAdUnitId({required bool isAndroid}) {
    if (useTestAds) {
      return isAndroid ? androidTestBanner : iosTestBanner;
    }
    return isAndroid ? androidProdBanner : iosProdBanner;
  }

  static String nativeAdUnitId({required bool isAndroid}) {
    if (useTestAds) {
      return isAndroid ? androidTestNative : iosTestNative;
    }
    return isAndroid ? androidProdNative : iosProdNative;
  }
}

/// Surfaces where ads are allowed. Critical flows are intentionally omitted.
enum AdPlacement {
  home,
  matchList,
  tournamentList,
  teamList,
  profile,
  searchResults,
}

/// Returns false for scoring, streaming, match creation, payments, auth, etc.
bool adsAllowedForRoute(String? location) {
  if (location == null || location.isEmpty) return false;
  final path = location.split('?').first;
  const blockedPrefixes = [
    '/login',
    '/register',
    '/onboarding',
    '/player-onboarding',
    '/match/create',
    '/scoring',
    '/store',
    '/payments',
  ];
  for (final p in blockedPrefixes) {
    if (path == p || path.startsWith('$p/')) return false;
  }
  // Live scoring & streaming studio under match hub
  if (path.contains('/score') ||
      path.contains('/live') ||
      path.contains('/stream') ||
      path.contains('/broadcast') ||
      path.contains('/studio') ||
      path.contains('/overlay')) {
    return false;
  }
  return true;
}

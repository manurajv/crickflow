import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Initializes the Mobile Ads SDK once at app start.
class AdMobService {
  AdMobService._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: const <String>[]),
        );
      }
      _initialized = true;
    } catch (e, st) {
      debugPrint('AdMob init failed: $e\n$st');
    }
  }
}

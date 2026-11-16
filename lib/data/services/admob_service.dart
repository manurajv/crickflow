import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/admob_config.dart';

/// Initializes the Mobile Ads SDK once at app start.
class AdMobService {
  AdMobService._();

  static bool _initialized = false;
  static bool _unavailable = false;
  static Future<void>? _initFuture;

  /// Samsung S911B debug hash from AdMob log — add more devices as needed.
  static const testDeviceIds = <String>[
    '504F3A9C22FEE080E5C4F9D655249F98',
  ];

  static bool get isInitialized => _initialized;

  /// True when the native plugin is missing (e.g. hot restart after adding the package).
  static bool get isUnavailable => _unavailable;

  static Future<void> initialize() {
    return _initFuture ??= _doInitialize();
  }

  static Future<void> _doInitialize() async {
    if (_initialized || _unavailable) return;
    try {
      // Let the first Flutter frame / WebView factory settle first.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _syncRemoteTestMode();
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds:
              AdMobConfig.useTestAds ? testDeviceIds : const <String>[],
        ),
      );
      _initialized = true;
    } on MissingPluginException catch (e) {
      _unavailable = true;
      debugPrint(
        'AdMob plugin not linked (stop app and do a full rebuild): $e',
      );
    } catch (e, st) {
      debugPrint('AdMob init failed: $e\n$st');
    }
  }

  /// Release builds honor `admin_admob_config/settings.testMode`.
  /// Missing or unreadable docs leave [AdMobConfig.remoteTestMode] null so
  /// production units stay in use (safe default for already-shipped releases).
  static Future<void> _syncRemoteTestMode() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('admin_admob_config')
          .doc('settings')
          .get()
          .timeout(const Duration(seconds: 5));
      AdMobConfig.applyRemoteConfig(snap.data());
    } catch (e) {
      AdMobConfig.applyRemoteConfig(null);
      debugPrint('AdMob remote testMode unavailable: $e');
    }
  }
}

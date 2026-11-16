import 'package:crickflow/config/admob_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => AdMobConfig.remoteTestMode = null);
  tearDown(() => AdMobConfig.remoteTestMode = null);

  test('applyRemoteConfig treats missing docs as unknown', () {
    expect(AdMobConfig.applyRemoteConfig(null), isNull);
    expect(AdMobConfig.remoteTestMode, isNull);
    expect(AdMobConfig.applyRemoteConfig(const {}), isNull);
    expect(AdMobConfig.remoteTestMode, isNull);
  });

  test('applyRemoteConfig stores an explicit testMode flag', () {
    expect(AdMobConfig.applyRemoteConfig({'testMode': true}), isTrue);
    expect(AdMobConfig.remoteTestMode, isTrue);
    expect(AdMobConfig.applyRemoteConfig({'testMode': false}), isFalse);
    expect(AdMobConfig.remoteTestMode, isFalse);
  });

  test('useTestAds is true in this debug test binding, even when remote is false', () {
    AdMobConfig.applyRemoteConfig({'testMode': false});
    // Widget tests run in debug; kDebugMode always forces test units.
    expect(AdMobConfig.useTestAds, isTrue);
  });
}

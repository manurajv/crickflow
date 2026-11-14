import 'package:crickflow/core/constants/prefs_keys.dart';
import 'package:crickflow/features/series/presentation/widgets/org_welcome_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('shows once per org until seen; neverAsk suppresses all', () async {
    final prefs = OrgWelcomePrefs(await SharedPreferences.getInstance());
    const uid = 'u1';
    expect(prefs.shouldShow(uid: uid, seriesId: 's1'), isTrue);
    expect(
      prefs.shouldShow(uid: uid, seriesId: 's1', forceFromCreate: true),
      isTrue,
    );

    await prefs.markSeen(uid, 's1');
    expect(prefs.shouldShow(uid: uid, seriesId: 's1'), isFalse);
    expect(prefs.shouldShow(uid: uid, seriesId: 's2'), isTrue);

    await prefs.setNeverAsk(uid, value: true);
    expect(prefs.shouldShow(uid: uid, seriesId: 's2'), isFalse);
    expect(
      prefs.shouldShow(uid: uid, seriesId: 's2', forceFromCreate: true),
      isFalse,
    );
  });

  test('dismiss with neverAskAgain sets both prefs', () async {
    final raw = await SharedPreferences.getInstance();
    final prefs = OrgWelcomePrefs(raw);
    await prefs.dismiss(uid: 'u1', seriesId: 's9', neverAskAgain: true);
    expect(raw.getBool(PrefsKeys.orgWelcomeSeen('u1', 's9')), isTrue);
    expect(raw.getBool(PrefsKeys.orgWelcomeNeverAsk('u1')), isTrue);
  });
}

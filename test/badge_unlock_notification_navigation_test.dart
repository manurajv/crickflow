import 'package:flutter_test/flutter_test.dart';
import 'package:crickflow/core/navigation/notification_navigation.dart';
import 'package:crickflow/features/my_cricket_profile/presentation/my_cricket_profile_screen.dart';

void main() {
  group('badge unlock navigation', () {
    test('opens my cricket profile badges tab', () {
      expect(
        NotificationNavigation.routeFor(
          type: 'badge_unlock',
          playerId: 'some-player-doc',
          tab: 'badges',
        ),
        '/my-cricket-profile?tab=badges',
      );
    });

    test('defaults tab to badges', () {
      expect(
        NotificationNavigation.routeFor(type: 'badge_unlock'),
        '/my-cricket-profile?tab=badges',
      );
    });

    test('tab index maps badges', () {
      expect(MyCricketProfileScreen.tabIndexFromName('badges'), 3);
      expect(MyCricketProfileScreen.tabIndexFromName('Badges'), 3);
    });
  });
}

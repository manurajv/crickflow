import 'package:crickflow/core/auth/auth_gate.dart';
import 'package:crickflow/core/auth/guest_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GuestRoutes — orgs browse', () {
    test('directory and org detail are public', () {
      for (final path in [
        '/series',
        '/associations',
        '/clubs',
        '/series/s1',
        '/series/s1/clubs/c1',
        '/series/s1/rankings',
        '/series/s1/fixtures',
      ]) {
        expect(GuestRoutes.isPublicRoute(path), isTrue, reason: path);
        expect(GuestRoutes.isProtectedRoute(path), isFalse, reason: path);
      }
    });

    test('org write routes are protected', () {
      for (final path in [
        '/series/create',
        '/series/create?family=clubs',
        '/series/s1/settings',
        '/series/s1/propose-match',
        '/series/s1/propose-tournament',
        '/series/s1/register',
        '/series/s1/my-requests',
        '/series/s1/admins',
        '/series/s1/audit',
        '/series/s1/approvals',
        '/series/s1/dashboard',
        '/series/s1/announcements',
        '/series/s1/clubs/create',
        '/series/s1/clubs/c1/add-player',
      ]) {
        expect(GuestRoutes.isProtectedRoute(path), isTrue, reason: path);
        expect(GuestRoutes.isPublicRoute(path), isFalse, reason: path);
      }
    });

    test('existing browse surfaces stay public; writes stay gated', () {
      expect(GuestRoutes.isPublicRoute('/home'), isTrue);
      expect(GuestRoutes.isPublicRoute('/match/abc'), isTrue);
      expect(GuestRoutes.isPublicRoute('/teams/t1'), isTrue);
      expect(GuestRoutes.isPublicRoute('/tournaments/t1'), isTrue);
      expect(GuestRoutes.isProtectedRoute('/match/start'), isTrue);
      expect(GuestRoutes.isProtectedRoute('/match/m1/score'), isTrue);
      expect(GuestRoutes.isProtectedRoute('/teams/create'), isTrue);
      expect(GuestRoutes.isProtectedRoute('/notifications'), isTrue);
      expect(GuestRoutes.isProtectedRoute('/profile/edit'), isTrue);
    });
  });

  group('PendingAuthAction', () {
    tearDown(PendingAuthAction.clear);

    test('login copy is exactly Login to use this', () {
      expect(kLoginToUseThisMessage, 'Login to use this');
      PendingAuthAction.register(path: '/series/s1/propose-match');
      expect(PendingAuthAction.hasPending, isTrue);
      expect(PendingAuthAction.promptMessage, 'Login to use this');
      expect(PendingAuthAction.returnPath, '/series/s1/propose-match');
    });
  });
}

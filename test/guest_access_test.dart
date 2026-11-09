import 'package:crickflow/core/auth/auth_gate.dart';
import 'package:crickflow/core/auth/guest_routes.dart';
import 'package:crickflow/core/auth/sign_in_prompts.dart';
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

  group('GuestRoutes.normalize', () {
    test('strips query, fragment, trailing slash', () {
      expect(GuestRoutes.normalize('/associations/'), '/associations');
      expect(GuestRoutes.normalize('/series/s1?tab=matches'), '/series/s1');
      expect(GuestRoutes.normalize('/clubs#x'), '/clubs');
    });
  });

  group('SignInPrompt', () {
    test('default message is professional fallback', () {
      expect(
        SignInPrompt.general.message,
        'Sign in to your CrickFlow account to continue.',
      );
      expect(kDefaultSignInMessage, SignInPrompt.general.message);
      expect(SignInPrompt.general.message.contains('log in'), isFalse);
      expect(SignInPrompt.general.message.contains('Login'), isFalse);
    });

    test('catalog has no Login / log in wording', () {
      for (final entry in SignInPrompt.byKey.entries) {
        expect(entry.value.message.toLowerCase().contains('log in'), isFalse,
            reason: entry.key);
        expect(entry.value.message.contains('Login'), isFalse, reason: entry.key);
        expect(entry.value.message.startsWith('Sign in'), isTrue,
            reason: entry.key);
      }
    });

    test('fromKey whitelist falls back to general', () {
      expect(SignInPrompt.fromKey('create_post'), SignInPrompt.createPost);
      expect(SignInPrompt.fromKey('nope'), SignInPrompt.general);
      expect(SignInPrompt.fromKey(null), SignInPrompt.general);
    });

    test('forPath maps protected routes', () {
      expect(SignInPrompt.forPath('/notifications'), SignInPrompt.notifications);
      expect(SignInPrompt.forPath('/match/start'), SignInPrompt.startMatch);
      expect(SignInPrompt.forPath('/match/m1/score'), SignInPrompt.scoreMatch);
      expect(
        SignInPrompt.forPath('/series/s1/propose-match'),
        SignInPrompt.proposeMatch,
      );
      expect(
        SignInPrompt.forPath('/series/create?family=clubs'),
        SignInPrompt.createOrg,
      );
      expect(SignInPrompt.forPath('/series/s1/register'), SignInPrompt.joinOrg);
    });

    test('contextual examples match product copy', () {
      expect(
        SignInPrompt.createPost.message,
        'Sign in to create a post and join the conversation.',
      );
      expect(
        SignInPrompt.startMatch.message,
        'Sign in to start a match and keep score.',
      );
      expect(SignInPrompt.createTeam.message, 'Sign in to create a team.');
      expect(
        SignInPrompt.proposeMatch.message,
        'Sign in to propose a match in this organization.',
      );
      expect(
        SignInPrompt.likeComment.message,
        'Sign in to like and comment on posts.',
      );
      expect(
        SignInPrompt.notifications.message,
        'Sign in to view your notifications.',
      );
      expect(
        SignInPrompt.manageProfile.message,
        'Sign in to manage your profile.',
      );
      expect(
        SignInPrompt.joinOrg.message,
        'Sign in to join this organization.',
      );
    });
  });

  group('PendingAuthAction', () {
    tearDown(PendingAuthAction.clear);

    test('stores contextual prompt for login banner', () {
      PendingAuthAction.register(
        path: '/series/s1/propose-match',
        prompt: SignInPrompt.proposeMatch,
      );
      expect(PendingAuthAction.hasPending, isTrue);
      expect(
        PendingAuthAction.promptMessage,
        SignInPrompt.proposeMatch.message,
      );
      expect(PendingAuthAction.returnPath, '/series/s1/propose-match');
    });
  });
}

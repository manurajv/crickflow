import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/notification_model.dart';
import 'package:crickflow/domain/notifications/notification_priority.dart';
import 'package:crickflow/features/notifications/presentation/notifications_screen.dart';
import 'package:crickflow/shared/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationModel _n(
  String id,
  String type, {
  bool read = false,
  bool? priority,
  String? teamId,
  String? playerId,
  String? requestId,
  String? matchId,
}) =>
    NotificationModel.fromMap(id, {
      'userId': 'me',
      'title': 'T $id',
      'body': 'B $id',
      'type': type,
      'read': read,
      'priority': ?priority,
      'teamId': ?teamId,
      'playerId': ?playerId,
      'requestId': ?requestId,
      'matchId': ?matchId,
      'createdAt': '2026-10-23T10:00:00.000Z',
    });

class _FakeFeed extends NotificationsFeedController {
  _FakeFeed(Ref ref, List<NotificationModel> items) : super(ref, null) {
    state = NotificationsFeedState(items: items, loading: false, hasMore: false);
  }
}

void main() {
  group('priority mapping', () {
    test('requests and their decisions are Priority', () {
      for (final t in [
        'team_join_request',
        'team_invitation',
        'tournament_join_request',
        'tournament_invitation',
        'tournament_official_invitation',
        'series_approval_pending',
        'series_approval_rejected',
        'team_join_accepted',
      ]) {
        expect(NotificationPriority.isPriorityType(t), isTrue, reason: t);
      }
    });

    test('match updates, results and achievements are General', () {
      for (final t in ['match_result', 'wicket', 'badge_unlock', 'player_follow']) {
        expect(NotificationPriority.isPriorityType(t), isFalse, reason: t);
      }
      expect(NotificationPriority.isPriorityType(null), isFalse);
    });

    test('server flag wins over the type fallback', () {
      expect(NotificationPriority.isPriority(_n('a', 'match_result', priority: true)),
          isTrue);
      expect(
          NotificationPriority.isPriority(
              _n('b', 'team_join_request', priority: false)),
          isFalse);
      expect(NotificationPriority.isPriority(_n('c', 'team_join_request')),
          isTrue);
    });

    test('unread counts per tab ignore read items', () {
      final counts = NotificationPriority.unreadCounts([
        _n('1', 'team_join_request'),
        _n('2', 'series_approval_pending'),
        _n('3', 'team_invitation', read: true),
        _n('4', 'match_result'),
      ]);
      expect(counts[NotificationTab.priority], 2);
      expect(counts[NotificationTab.general], 1);
    });
  });

  group('related notifications', () {
    test('team join request copies match by team + requester', () {
      final rel = NotificationRelation.of(
        _n('x', 'team_join_request', teamId: 't', playerId: 'u1'),
      )!;
      expect(rel.matches(_n('dup', 'team_join_request', teamId: 't', playerId: 'u1')),
          isTrue);
      expect(rel.matches(_n('o', 'team_join_request', teamId: 't', playerId: 'u2')),
          isFalse);
      expect(rel.matches(_n('o2', 'team_join_accepted', teamId: 't', playerId: 'u1')),
          isFalse);
    });

    test('tournament and org requests match by request id and request type', () {
      final t = NotificationRelation.of(
        _n('x', 'tournament_join_request', requestId: 'r1'),
      )!;
      expect(t.matches(_n('d', 'tournament_join_request', requestId: 'r1')), isTrue);
      expect(t.matches(_n('e', 'tournament_join_approved', requestId: 'r1')), isFalse);
      final s = NotificationRelation.of(
        _n('y', 'series_approval_pending', requestId: 'a1'),
      )!;
      expect(s.matches(_n('d', 'series_approval_pending', requestId: 'a1')), isTrue);
      expect(s.matches(_n('e', 'series_approval_approved', requestId: 'a1')), isFalse);
    });

    test('match notifications match by match id', () {
      final m = NotificationRelation.of(_n('x', 'wicket', matchId: 'm1'))!;
      expect(m.matches(_n('r', 'match_result', matchId: 'm1')), isTrue);
      expect(m.matches(_n('o', 'match_result', matchId: 'm2')), isFalse);
      expect(NotificationRelation.of(_n('z', 'player_follow')), isNull);
    });

    test('push payload fields build the same relation', () {
      final rel = NotificationRelation.fromFields(
        type: 'team_join_request',
        teamId: 't',
        playerId: 'u1',
      )!;
      expect(rel.matches(_n('d', 'team_join_request', teamId: 't', playerId: 'u1')),
          isTrue);
    });
  });

  testWidgets('screen splits into Priority / General with unread badges',
      (tester) async {
    final items = [
      _n('p1', 'team_join_request', teamId: 't', playerId: 'u1'),
      _n('g1', 'match_result', matchId: 'm1'),
      _n('g2', 'badge_unlock', read: true),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsFeedProvider.overrideWith((ref) => _FakeFeed(ref, items)),
          notificationUnreadByTabProvider.overrideWith(
            (ref) => Stream.value(NotificationPriority.unreadCounts(items)),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    // One unread in each tab.
    expect(
      find.descendant(
        of: find.byKey(const Key('notifications_tab_priority')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('T p1'), findsOneWidget);
    expect(find.text('T g1'), findsNothing);

    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    expect(find.text('T g1'), findsOneWidget);
    expect(find.text('T g2'), findsOneWidget);
    expect(find.text('T p1'), findsNothing);
  });
}

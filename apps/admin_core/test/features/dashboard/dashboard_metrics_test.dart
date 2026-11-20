import 'package:crickflow_admin_core/features/dashboard/data/dashboard_metrics.dart';
import 'package:crickflow_admin_core/features/dashboard/models/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDashboardCount', () {
    test('formats thousands and compact millions', () {
      expect(formatDashboardCount(0), '0');
      expect(formatDashboardCount(12), '12');
      expect(formatDashboardCount(12480), '12,480');
      expect(formatDashboardCount(1000000), '1M');
      expect(formatDashboardCount(-1), '—');
    });
  });

  group('relativeDashboardTime', () {
    final now = DateTime(2026, 11, 16, 17, 0);
    test('uses minutes, hours, and calendar days', () {
      expect(
        relativeDashboardTime(now.subtract(const Duration(seconds: 20)), now: now),
        'Just now',
      );
      expect(
        relativeDashboardTime(now.subtract(const Duration(minutes: 4)), now: now),
        '4m ago',
      );
      expect(
        relativeDashboardTime(now.subtract(const Duration(hours: 5)), now: now),
        '5h ago',
      );
      expect(
        relativeDashboardTime(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday',
      );
    });
  });

  test('recentMatchFromMap uses live status, names, and score', () {
    final item = recentMatchFromMap('m1', {
      'title': 'Sunday Super League',
      'teamAName': 'Titans',
      'teamBName': 'Strikers',
      'status': 'live',
      'live': {'runs': 148, 'wickets': 4},
    });
    expect(item.title, 'Sunday Super League');
    expect(item.teamA, 'Titans');
    expect(item.isLive, isTrue);
    expect(item.status, 'Live');
    expect(item.score, '148/4');
  });

  test('recentUserFromMap falls back to display name', () {
    final item = recentUserFromMap('u9', {
      'displayName': 'Nimali Silva',
      'country': 'Sri Lanka',
      'accountStatus': 'active',
      'createdAt': DateTime(2026, 11, 16, 15).toIso8601String(),
    }, now: DateTime(2026, 11, 16, 17));
    expect(item.name, 'Nimali Silva');
    expect(item.country, 'Sri Lanka');
    expect(item.joinedLabel, '2h ago');
    expect(item.id, 'u9');
  });

  test('recentReportFromMap never invents a reporter', () {
    final item = recentReportFromMap('r1', {
      'reporterUserId': 'guest_92',
      'reason': 'Spam in community',
      'status': 'pending',
    });
    expect(item.userName, 'guest_92');
    expect(item.reason, 'Spam in community');
    expect(item.status, isNotEmpty);
  });

  test('activityFromUser skips rows without createdAt', () {
    expect(activityFromUser('u1', {'displayName': 'A'}), isNull);
    final item = activityFromUser('u1', {
      'displayName': 'Ayesha',
      'createdAt': '2026-11-16T10:00:00.000Z',
    });
    expect(item, isNotNull);
    expect(item!.kind, ActivityKind.userRegistered);
    expect(item.subtitle, 'Ayesha');
  });

  test('matchIsLive includes innings break', () {
    expect(matchIsLive('live'), isTrue);
    expect(matchIsLive('inningsBreak'), isTrue);
    expect(matchIsLive('completed'), isFalse);
    expect(matchIsLive(null), isFalse);
  });
}

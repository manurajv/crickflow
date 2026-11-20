import 'package:crickflow_admin_core/features/monitoring/models/monitoring_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('colomboDateId uses IST (UTC+5:30)', () {
    // 16 Nov 2026 18:30Z is 17 Nov 2026 00:00 IST
    expect(
      PlatformDailyStat.colomboDateId(DateTime.utc(2026, 11, 16, 18, 30)),
      '2026-11-17',
    );
    expect(
      PlatformDailyStat.colomboDateId(DateTime.utc(2026, 11, 16, 12, 0)),
      '2026-11-16',
    );
  });

  test('fromMap reads counts and mergeLiveToday replaces the same day', () {
    final history = [
      PlatformDailyStat.fromMap('2026-11-14', {'users': 10, 'matches': 2}),
      PlatformDailyStat.fromMap('2026-11-15', {
        'date': '2026-11-15',
        'users': 12,
        'teams': 3,
      }),
    ];
    final today = PlatformDailyStat(
      date: '2026-11-15',
      users: 15,
      teams: 4,
      matches: 7,
      isLiveToday: true,
    );
    final merged = PlatformDailyStat.mergeLiveToday(history: history, today: today);
    expect(merged.map((e) => e.date), ['2026-11-14', '2026-11-15']);
    expect(merged.last.users, 15);
    expect(merged.last.isLiveToday, isTrue);
    expect(merged.first.trackedDocuments, 12); // 10 users + 2 matches
  });
}

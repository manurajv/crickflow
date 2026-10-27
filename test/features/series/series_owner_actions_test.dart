import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/domain/services/series/series_owner_actions.dart';
import 'package:flutter_test/flutter_test.dart';

SeriesModel _series({
  SeriesStatus status = SeriesStatus.active,
  bool hold = false,
  String? owner = 'owner',
  String? createdBy = 'owner',
}) =>
    SeriesModel.fromMap('s1', {
      'name': 'Series One',
      'status': status.name,
      'platformHold': hold,
      'superAdminUserId': ?owner,
      'createdBy': ?createdBy,
    });

SeriesAdminModel _admin(String uid, {String status = 'active'}) =>
    SeriesAdminModel.fromMap('s1_$uid', {
      'seriesId': 's1',
      'userId': uid,
      'status': status,
    });

void main() {
  const actions = SeriesOwnerActions();

  group('lifecycleActions', () {
    test('active and draft orgs can be archived', () {
      expect(actions.lifecycleActions(_series()), [SeriesLifecycleAction.archive]);
      expect(
        actions.lifecycleActions(_series(status: SeriesStatus.draft)),
        [SeriesLifecycleAction.archive],
      );
    });

    test('archived and owner-suspended orgs can be reactivated', () {
      expect(
        actions.lifecycleActions(_series(status: SeriesStatus.archived)),
        [SeriesLifecycleAction.reactivate],
      );
      expect(
        actions.lifecycleActions(_series(status: SeriesStatus.suspended)),
        [SeriesLifecycleAction.reactivate, SeriesLifecycleAction.archive],
      );
    });

    test('platform hold blocks every owner action', () {
      expect(
        actions.lifecycleActions(
          _series(status: SeriesStatus.suspended, hold: true),
        ),
        isEmpty,
      );
    });
  });

  group('transferCandidates', () {
    test('active admins except the owner, de-duplicated', () {
      final list = actions.transferCandidates(
        series: _series(),
        admins: [
          _admin('owner'),
          _admin('a1'),
          _admin('a1'),
          _admin('a2', status: 'removed'),
          _admin('a3'),
        ],
      );
      expect(list.map((a) => a.userId), ['a1', 'a3']);
    });

    test('falls back to createdBy as owner for drafts', () {
      final list = actions.transferCandidates(
        series: _series(owner: null, createdBy: 'c'),
        admins: [_admin('c'), _admin('d')],
      );
      expect(list.map((a) => a.userId), ['d']);
    });
  });

  test('statusMessage explains platform holds', () {
    expect(
      actions.statusMessage(_series(status: SeriesStatus.suspended, hold: true)),
      contains('CrickFlow'),
    );
    expect(actions.statusMessage(_series()), startsWith('Active'));
  });

  test('announcement model parses audience and counts', () {
    final a = SeriesAnnouncementModel.fromMap('an1', {
      'seriesId': 's1',
      'title': 'Fixtures out',
      'body': 'See the fixtures tab',
      'audience': 'members',
      'recipientCount': 12,
      'createdAt': '2026-10-08T10:00:00.000Z',
    });
    expect(a.audience, SeriesAnnouncementAudience.members);
    expect(a.audience.label, 'Players');
    expect(a.recipientCount, 12);
    expect(SeriesAnnouncementAudience.parse('nope'), SeriesAnnouncementAudience.all);
  });
}

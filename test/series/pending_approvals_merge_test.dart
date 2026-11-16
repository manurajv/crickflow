import 'dart:async';

import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/data/repositories/series_approval_repository.dart';
import 'package:flutter_test/flutter_test.dart';

SeriesApprovalModel _item(
  String id, {
  DateTime? requestedAt,
  String name = '',
}) => SeriesApprovalModel(
  id: id,
  seriesId: 's1',
  targetType: SeriesApprovalTargetType.clubRegistration,
  targetId: id,
  requestedBy: 'u1',
  requestedAt: requestedAt,
  metadata: name.isEmpty ? const {} : {'displayName': name},
);

void main() {
  test('merge unions by id, later lists win, newest first', () {
    final older = _item('a', requestedAt: DateTime(2026, 1, 1), name: 'old');
    final newer = _item('b', requestedAt: DateTime(2026, 2, 1));
    final updated = _item('a', requestedAt: DateTime(2026, 1, 1), name: 'new');

    final merged = mergePendingApprovalLists([
      [older, newer],
      [updated],
    ]);
    expect(merged.map((e) => e.id).toList(), ['b', 'a']);
    expect(merged.last.metadata['displayName'], 'new');
  });

  test('merge skips null or empty sources so one queue can paint alone', () {
    final only = _item('x', requestedAt: DateTime(2026, 3, 1));
    expect(
      mergePendingApprovalLists([
        null,
        [only],
        const [],
      ]).single.id,
      'x',
    );
  });

  test('combined streams emit as soon as the first source has data', () async {
    final late = StreamController<List<SeriesApprovalModel>>();
    final early = StreamController<List<SeriesApprovalModel>>();
    final events = <List<String>>[];

    final sub = combineLatestApprovalStreams([
      late.stream,
      early.stream,
    ]).listen((items) => events.add(items.map((e) => e.id).toList()));

    early.add([_item('fast', requestedAt: DateTime(2026, 4, 1))]);
    await Future<void>.delayed(Duration.zero);
    expect(events, [
      ['fast'],
    ]);

    late.add([_item('slow', requestedAt: DateTime(2026, 5, 1))]);
    await Future<void>.delayed(Duration.zero);
    expect(events.last, ['slow', 'fast']);

    await sub.cancel();
    await late.close();
    await early.close();
  });

  test(
    'combined streams surface an error only when every source fails',
    () async {
      final a = StreamController<List<SeriesApprovalModel>>();
      final b = StreamController<List<SeriesApprovalModel>>();
      final events = <List<String>>[];
      Object? error;

      final sub = combineLatestApprovalStreams([a.stream, b.stream]).listen(
        (items) => events.add(items.map((e) => e.id).toList()),
        onError: (Object e, _) => error = e,
      );

      a.addError(Exception('denied'));
      await Future<void>.delayed(Duration.zero);
      expect(error, isNull);
      expect(events, isEmpty);

      b.add([_item('ok', requestedAt: DateTime(2026, 6, 1))]);
      await Future<void>.delayed(Duration.zero);
      expect(error, isNull);
      expect(events, [
        ['ok'],
      ]);

      await sub.cancel();
      await a.close();
      await b.close();
    },
  );
}

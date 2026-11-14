import 'dart:async';

import 'package:crickflow/core/startup/startup_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StartupTrace.capped', () {
    test('returns the value when the work finishes in time', () async {
      final v = await StartupTrace.capped<int>(
        Future.value(7),
        timeout: const Duration(milliseconds: 200),
        fallback: 0,
      );
      expect(v, 7);
    });

    test('falls back when slow work would block startup', () async {
      final slow = Completer<int>();
      final sw = Stopwatch()..start();
      final v = await StartupTrace.capped<int>(
        slow.future,
        timeout: const Duration(milliseconds: 50),
        fallback: -1,
      );
      expect(v, -1);
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('falls back on errors (e.g. offline profile read)', () async {
      final v = await StartupTrace.capped<String?>(
        Future<String?>.error(StateError('offline')),
        timeout: const Duration(seconds: 1),
        fallback: null,
      );
      expect(v, isNull);
    });
  });
}

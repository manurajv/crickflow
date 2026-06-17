import 'package:crickflow/core/utils/overs_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatOvers', () {
    test('4 balls per over — 4 legal balls = 1.0', () {
      expect(OversFormatter.formatOvers(4, 4), '1.0');
    });

    test('4 balls per over — 8 legal balls = 2.0', () {
      expect(OversFormatter.formatOvers(8, 4), '2.0');
    });

    test('4 balls per over — 7 legal balls = 1.3', () {
      expect(OversFormatter.formatOvers(7, 4), '1.3');
    });

    test('5 balls per over — 12 legal balls = 2.2', () {
      expect(OversFormatter.formatOvers(12, 5), '2.2');
    });

    test('8 balls per over — 16 legal balls = 2.0', () {
      expect(OversFormatter.formatOvers(16, 8), '2.0');
    });

    test('4-ball match — 59 legal balls = 14.3', () {
      expect(OversFormatter.formatOvers(59, 4), '14.3');
    });

    test('4-ball live — 13 legal balls = 3.1', () {
      expect(OversFormatter.formatOvers(13, 4), '3.1');
    });
  });

  group('calculateOvers', () {
    test('8 legal balls @ 4 bpo = 2.0 actual overs', () {
      expect(OversFormatter.calculateOvers(8, 4), 2.0);
    });
  });

  group('calculateEconomy', () {
    test('12 runs off 8 legal balls @ 4 bpo = 6.00', () {
      expect(
        OversFormatter.calculateEconomy(12, 8, 4),
        closeTo(6.0, 0.001),
      );
    });

    test('not 12 / 1.2 when wrongly using six-ball notation', () {
      expect(
        OversFormatter.calculateEconomy(12, 8, 4),
        isNot(closeTo(10.0, 0.001)),
      );
    });
  });

  group('calculateRunRate', () {
    test('40 runs in 20 legal balls @ 4 bpo (5 overs) = 8.00', () {
      expect(
        OversFormatter.calculateRunRate(40, 20, 4),
        closeTo(8.0, 0.001),
      );
    });
  });

  group('calculateRequiredRunRate', () {
    test('needs 24 off 8 balls @ 4 bpo = 12.00', () {
      expect(
        OversFormatter.calculateRequiredRunRate(
          runsNeeded: 24,
          ballsRemaining: 8,
          ballsPerOver: 4,
        ),
        closeTo(12.0, 0.001),
      );
    });
  });
}

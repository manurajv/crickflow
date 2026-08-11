import 'package:flutter_test/flutter_test.dart';
import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/utils/currency_utils.dart';
import 'package:crickflow/data/models/tournament/tournament_setup_meta.dart';

void main() {
  group('currencyCodeForCountry', () {
    test('maps cricket nations', () {
      expect(currencyCodeForCountry('Sri Lanka'), 'LKR');
      expect(currencyCodeForCountry('India'), 'INR');
      expect(currencyCodeForCountry('LK'), 'LKR');
      expect(currencyCodeForCountry('AU'), 'AUD');
    });

    test('unknown returns empty', () {
      expect(currencyCodeForCountry(''), '');
      expect(currencyCodeForCountry('Narnia'), '');
    });

    test('budget section label', () {
      expect(
        budgetRangeSectionLabel(base: 'Per day', countryOrCode: 'Sri Lanka'),
        'Per day (in LKR):',
      );
      expect(
        budgetRangeSectionLabel(base: 'Per day', countryOrCode: null),
        'Per day:',
      );
    });

    test('formats entry fee by country', () {
      expect(
        formatCurrencyAmount(500, countryOrCode: 'Sri Lanka'),
        'Rs.500',
      );
      expect(
        formatCurrencyAmount(500, countryOrCode: 'India'),
        '₹500',
      );
    });
  });

  group('per-role budgets', () {
    test('summary lines differ by role', () {
      const meta = TournamentSetupMeta(
        sameBudgetForAll: false,
        budgetCurrencyCode: 'LKR',
        requiredOfficialRoles: {
          TournamentOfficialRole.umpire,
          TournamentOfficialRole.scorer,
        },
        budgetPerDayByRole: {
          TournamentOfficialRole.umpire: OfficialBudgetBand.day500to1000,
        },
        budgetPerMatchByRole: {
          TournamentOfficialRole.scorer: OfficialBudgetBand.match100to500,
        },
      );
      final lines = officialBudgetSummaryLines(meta);
      expect(lines, contains('Umpire: 500 - 1000 LKR/day'));
      expect(lines, contains('Scorer: 100 - 500 LKR/match'));
    });

    test('round-trips by-role maps', () {
      const meta = TournamentSetupMeta(
        sameBudgetForAll: false,
        budgetCurrencyCode: 'INR',
        budgetPerDayByRole: {
          TournamentOfficialRole.umpire: OfficialBudgetBand.day2000plus,
        },
      );
      final restored = TournamentSetupMeta.fromMap(meta.toMap());
      expect(restored.budgetCurrencyCode, 'INR');
      expect(
        restored.budgetPerDayByRole[TournamentOfficialRole.umpire],
        OfficialBudgetBand.day2000plus,
      );
    });
  });
}

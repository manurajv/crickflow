import 'package:crickflow_admin_core/core/export/admin_csv.dart';
import 'package:crickflow_admin_core/core/export/admin_file_download.dart';
import 'package:crickflow_admin_core/core/export/admin_list_exports.dart';
import 'package:crickflow_admin_core/features/matches/models/managed_match.dart';
import 'package:crickflow_admin_core/features/users/models/managed_user.dart';
import 'package:crickflow_admin_core/features/users/models/user_account_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminCsv', () {
    test('escapes commas, quotes, and newlines', () {
      expect(AdminCsv.escape('plain'), 'plain');
      expect(AdminCsv.escape('a,b'), '"a,b"');
      expect(AdminCsv.escape('say "hi"'), '"say ""hi"""');
      expect(AdminCsv.escape('line\nbreak'), '"line\nbreak"');
    });

    test('builds a plain CSV and an Excel-compatible CSV with a BOM', () {
      const headers = ['id', 'name'];
      final rows = [
        ['1', 'Alpha, team'],
        ['2', 'Beta'],
      ];
      final csv = AdminCsv.table(headers: headers, rows: rows);
      expect(csv.startsWith(AdminCsv.bom), isFalse);
      expect(csv, contains('id,name'));
      expect(csv, contains('"Alpha, team"'));

      final excel = AdminCsv.table(
        headers: headers,
        rows: rows,
        excelCompatible: true,
      );
      expect(excel.startsWith(AdminCsv.bom), isTrue);
      expect(excel.substring(1), csv);
    });

    test('pads short rows to the header length', () {
      final csv = AdminCsv.table(
        headers: ['a', 'b', 'c'],
        rows: [
          ['1'],
        ],
      );
      expect(csv.trim().split('\n').last, '1,,');
    });
  });

  test('downloadTextFile is a no-op on the VM test stub', () {
    final result = downloadTextFile(filename: 'test.csv', content: 'id\n1');
    expect(result.downloaded, isFalse);
    expect(result.filename, 'test.csv');
  });

  test('user export rows match the header count', () {
    final user = ManagedUser(
      id: 'u1',
      email: 'a@example.com',
      name: 'Ada',
      accountStatus: UserAccountStatus.active,
    );
    expect(
      AdminListExports.userRow(user).length,
      AdminListExports.userHeaders.length,
    );
  });

  test('MatchSetupSummary reads playing XI, officials, and innings', () {
    final summary = MatchSetupSummary.fromMaps(
      setup: {
        'teamAPlayingPlayers': [
          {'name': 'Rohit'},
          {'playerName': 'Kohli'},
        ],
        'teamBPlayingPlayers': [
          {'fullName': 'Smith'},
        ],
        'umpires': [
          {'name': 'Aleem Dar'},
        ],
        'scorers': ['Priya'],
        'referee': {'name': 'Match Ref'},
      },
      innings: [
        {
          'battingTeamName': 'India',
          'totalRuns': 178,
          'totalWickets': 4,
          'legalBalls': 120,
        },
      ],
    );
    expect(summary.teamAXi, ['Rohit', 'Kohli']);
    expect(summary.teamBXi, ['Smith']);
    expect(summary.umpires, ['Aleem Dar']);
    expect(summary.scorers, ['Priya']);
    expect(summary.referee, 'Match Ref');
    expect(summary.inningsLines.single, 'India 178/4 (20.0 ov)');
    expect(summary.hasSquad, isTrue);
    expect(summary.hasOfficials, isTrue);
    expect(summary.hasScorecard, isTrue);
  });
}

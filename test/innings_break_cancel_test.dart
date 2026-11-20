import 'package:crickflow/core/constants/enums.dart';
import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/innings_model.dart';
import 'package:crickflow/data/models/match_model.dart';
import 'package:crickflow/features/scoring/presentation/widgets/innings_break_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _inn = InningsModel(
  inningsNumber: 1,
  battingTeamId: 'a',
  bowlingTeamId: 'b',
  status: InningsStatus.inProgress,
  totalRuns: 120,
  totalWickets: 10,
  legalBalls: 100,
);

final _match = MatchModel(
  id: 'm1',
  title: 'A vs B',
  teamAId: 'a',
  teamBId: 'b',
  teamAName: 'Alpha',
  teamBName: 'Bravo',
  status: MatchStatus.live,
  innings: const [_inn],
);

Future<({bool? result, int confirms})> _run(
  WidgetTester tester,
  Future<void> Function() dismiss,
) async {
  bool? result;
  var confirms = 0;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              result = await InningsBreakDialog.show(
                context,
                match: _match,
                innings: _inn,
                allowUndo: true,
                onUndo: () {},
                onConfirm: () async => confirms++,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byKey(InningsBreakDialog.cancelKey), findsOneWidget);
  await dismiss();
  await tester.pumpAndSettle();
  expect(find.byKey(InningsBreakDialog.cancelKey), findsNothing);
  return (result: result, confirms: confirms);
}

void main() {
  testWidgets('Cancel button closes the slide sheet without confirming',
      (tester) async {
    final r = await _run(
        tester, () => tester.tap(find.byKey(InningsBreakDialog.cancelKey)));
    expect(r.result, isTrue);
    expect(r.confirms, 0);
  });

  testWidgets('back gesture closes the slide sheet', (tester) async {
    final r = await _run(tester, () async {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      await nav.maybePop();
    });
    expect(r.result, isTrue);
    expect(r.confirms, 0);
  });

  testWidgets('tapping outside closes the slide sheet', (tester) async {
    final r = await _run(tester, () => tester.tapAt(const Offset(10, 10)));
    expect(r.result, isTrue);
    expect(r.confirms, 0);
  });
}

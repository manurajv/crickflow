import 'dart:async';

import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/features/series/presentation/series_approvals_screen.dart';
import 'package:crickflow/features/series/presentation/series_detail_screen.dart';
import 'package:crickflow/shared/providers/series_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.darkTheme, home: child),
    );

List<Override> _roleAndQueue({
  SeriesRole role = SeriesRole.seriesAdmin,
  Stream<List<SeriesApprovalModel>>? stream,
}) => [
  mySeriesRoleProvider('s1').overrideWith((_) => role),
  if (stream != null)
    pendingSeriesApprovalsProvider('s1').overrideWith((_) => stream),
];

SeriesModel _org() => SeriesModel.fromMap('s1', {
  'name': 'City League',
  'status': 'active',
  'kind': 'series',
  'superAdminUserId': 'owner',
  'clubCount': 3,
  'matchCount': 8,
  'tournamentCount': 2,
});

void main() {
  testWidgets('shows a skeleton while pending approvals are loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SeriesApprovalsScreen(seriesId: 's1'),
        overrides: _roleAndQueue(stream: const Stream.empty()),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('org_approvals_skeleton')), findsOneWidget);
  });

  testWidgets('empty queue shows a centered all-caught-up state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SeriesApprovalsScreen(seriesId: 's1'),
        overrides: _roleAndQueue(stream: Stream.value(const [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
    expect(
      find.text("There's nothing waiting for your approval right now."),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.task_alt), findsOneWidget);
  });

  testWidgets('error state offers Retry', (tester) async {
    await tester.pumpWidget(
      _app(
        const SeriesApprovalsScreen(seriesId: 's1'),
        overrides: _roleAndQueue(
          stream: Stream.error(Exception('unavailable')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not load approvals'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'overview stat tiles call onOpenTab for teams, matches, tournaments',
    (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: OrgOverviewStatTiles(series: _org(), onOpenTab: opened.add),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('org_overview_stat_teams')));
      await tester.tap(find.byKey(const Key('org_overview_stat_matches')));
      await tester.tap(find.byKey(const Key('org_overview_stat_tournaments')));
      expect(opened, ['teams', 'matches', 'tournaments']);
    },
  );

  testWidgets('selectTab animates the same TabController', (tester) async {
    late TabController tabs;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: DefaultTabController(
          length: SeriesDetailScreen.tabSlugs.length,
          child: Builder(
            builder: (context) {
              tabs = DefaultTabController.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(tabs.index, 0);
    SeriesDetailScreen.selectTab(tabs, 'matches');
    await tester.pumpAndSettle();
    expect(tabs.index, 1);
    SeriesDetailScreen.selectTab(tabs, 'tournaments');
    await tester.pumpAndSettle();
    expect(tabs.index, 2);
    SeriesDetailScreen.selectTab(tabs, 'teams');
    await tester.pumpAndSettle();
    expect(tabs.index, 4);
  });
}

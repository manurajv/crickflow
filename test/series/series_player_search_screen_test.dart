import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/features/series/presentation/widgets/series_player_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search screen shows a professional empty state and search bar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SeriesPlayerSearchScreen(title: 'Search & add player'),
      ),
    );
    await tester.pump();
    expect(find.text('Search & add player'), findsOneWidget);
    expect(find.byKey(const Key('org_player_search_field')), findsOneWidget);
    expect(
      find.text('Type a name or CrickFlow ID to find players'),
      findsOneWidget,
    );
  });
}

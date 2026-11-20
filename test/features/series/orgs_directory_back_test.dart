import 'package:crickflow/core/routing/pop_or_home.dart';
import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/data/models/series/series.dart';
import 'package:crickflow/data/models/user_model.dart';
import 'package:crickflow/features/series/presentation/orgs_directory_screen.dart';
import 'package:crickflow/shared/providers/providers.dart';
import 'package:crickflow/shared/providers/series_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

List<Override> _guestOverrides() => [
      listActiveSeriesProvider
          .overrideWith((_) => Stream.value(const <SeriesModel>[])),
      authStateProvider.overrideWith((_) => Stream<User?>.value(null)),
      currentUserProfileProvider.overrideWith((_) async => null as UserModel?),
    ];

GoRouter _router({String initial = '/associations'}) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('HOME')),
          ),
        ),
        GoRoute(
          path: '/associations',
          builder: (_, __) =>
              const OrgsDirectoryScreen(family: OrgFamily.associations),
        ),
        GoRoute(
          path: '/clubs',
          builder: (_, __) =>
              const OrgsDirectoryScreen(family: OrgFamily.clubs),
        ),
        GoRoute(
          path: '/series',
          builder: (_, __) =>
              const OrgsDirectoryScreen(family: OrgFamily.series),
        ),
      ],
    );

Widget _app(GoRouter router) => ProviderScope(
      overrides: _guestOverrides(),
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );

void main() {
  testWidgets('Associations directory always shows a back control',
      (tester) async {
    await tester.pumpWidget(_app(_router()));
    await tester.pumpAndSettle();

    expect(find.text('Associations'), findsWidgets);
    expect(find.byType(CfBackOrHomeButton), findsOneWidget);
  });

  testWidgets('back goes to /home when the stack is empty (go entry)',
      (tester) async {
    // initialLocation uses go semantics — nothing under Associations.
    await tester.pumpWidget(_app(_router(initial: '/associations')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CfBackOrHomeButton));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(OrgsDirectoryScreen), findsNothing);
  });

  testWidgets('back pops to previous route when the stack has an entry',
      (tester) async {
    final router = _router(initial: '/home');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.push('/clubs');
    await tester.pumpAndSettle();
    expect(find.text('Clubs'), findsWidgets);
    expect(find.byType(CfBackOrHomeButton), findsOneWidget);

    await tester.tap(find.byType(CfBackOrHomeButton));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('popOrGoHome pops when possible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              leading: CfBackOrHomeButton(
                onPressed: () => popOrGoHome(context),
              ),
            ),
            body: const Text('ROOT'),
          ),
        ),
        routes: {
          '/child': (_) => Builder(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    leading: CfBackOrHomeButton(
                      onPressed: () => popOrGoHome(context),
                    ),
                  ),
                  body: const Text('CHILD'),
                ),
              ),
        },
      ),
    );
    await tester.pumpAndSettle();

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed('/child');
    await tester.pumpAndSettle();
    expect(find.text('CHILD'), findsOneWidget);

    await tester.tap(find.byType(CfBackOrHomeButton));
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);
  });
}

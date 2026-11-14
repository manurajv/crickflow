import 'package:crickflow/core/theme/app_theme.dart';
import 'package:crickflow/features/series/presentation/widgets/series_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SeriesEmptyState centers title and message in bounded space', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: SeriesEmptyState(
              icon: Icons.task_alt,
              title: 'All caught up',
              message: 'There are no pending approvals.',
            ),
          ),
        ),
      ),
    );

    final title = tester.getCenter(find.text('All caught up'));
    final message = tester.getCenter(
      find.text('There are no pending approvals.'),
    );
    final box = tester.getRect(find.byType(SizedBox).first);

    expect(title.dx, closeTo(box.center.dx, 1));
    expect(message.dx, closeTo(box.center.dx, 1));
    // Vertically near middle of the available area (allow some padding slack).
    expect(title.dy, greaterThan(box.top + box.height * 0.25));
    expect(title.dy, lessThan(box.top + box.height * 0.75));
  });
}

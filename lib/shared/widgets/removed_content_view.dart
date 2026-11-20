import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown when a team / tournament / organization / match was deleted
/// (by its owner or by CrickFlow) and is no longer available.
class RemovedContentView extends StatelessWidget {
  const RemovedContentView({super.key, required this.kind});

  /// e.g. 'team', 'tournament', 'organization', 'match'.
  final String kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: const Key('removed_content_view'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'This $kind was removed',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              "It was deleted and is no longer available.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

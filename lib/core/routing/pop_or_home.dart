import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pops the current route, or navigates to `/home` when nothing is under it.
///
/// Use for top-level browse screens (e.g. Orgs directories) that may be opened
/// with [GoRouter.go] (no stack) or deep links, so the user is never trapped.
void popOrGoHome(BuildContext context) {
  if (!context.mounted) return;

  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
    return;
  }

  final nav = Navigator.maybeOf(context);
  if (nav != null && nav.canPop()) {
    nav.pop();
  }
}

/// App-bar leading control that always offers a way back to the shell.
class CfBackOrHomeButton extends StatelessWidget {
  const CfBackOrHomeButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => popOrGoHome(context),
    );
  }
}

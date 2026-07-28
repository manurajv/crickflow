import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/cf_shell_bottom_nav.dart';

/// Root shell with custom bottom navigation
/// (Home · Discover · My Cricket · Community · Profile).
class MainShellScaffold extends StatelessWidget {
  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: CfShellBottomNav(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
      ),
    );
  }
}

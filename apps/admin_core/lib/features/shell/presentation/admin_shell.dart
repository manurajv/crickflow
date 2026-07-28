import 'package:flutter/material.dart';

import 'widgets/admin_sidebar.dart';
import 'widgets/admin_top_bar.dart';

/// Shared admin chrome: left nav + top bar + scrollable content.
///
/// Right side panels are reserved via [endDrawer] for future use.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.child,
    this.endDrawer,
  });

  final Widget child;
  final Widget? endDrawer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: endDrawer,
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                const AdminTopBar(),
                Expanded(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

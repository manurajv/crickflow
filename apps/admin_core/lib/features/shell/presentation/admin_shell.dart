import 'package:flutter/material.dart';

import '../../../core/constants/breakpoints.dart';
import 'widgets/admin_sidebar.dart';
import 'widgets/admin_top_bar.dart';

/// Shared admin chrome: responsive sidebar/drawer + top bar + content.
///
/// - Mobile (< tablet): Drawer with hamburger menu
/// - Desktop (>= tablet): Persistent sidebar
class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.child,
    this.endDrawer,
  });

  final Widget child;
  final Widget? endDrawer;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < Breakpoints.drawerBreakpoint;

        return Scaffold(
          key: _scaffoldKey,
          endDrawer: widget.endDrawer,
          drawer: isMobile
              ? Drawer(
                  width: Breakpoints.sidebarExpanded,
                  child: const AdminSidebar(),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile) const AdminSidebar(),
              Expanded(
                child: Column(
                  children: [
                    AdminTopBar(
                      showMenuButton: isMobile,
                      onMenuTap: isMobile
                          ? () => _scaffoldKey.currentState?.openDrawer()
                          : null,
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

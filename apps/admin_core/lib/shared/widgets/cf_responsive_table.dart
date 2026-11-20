import 'package:flutter/material.dart';

import '../../core/constants/breakpoints.dart';

/// Wraps a DataTable to make it horizontally scrollable on narrow viewports.
///
/// On mobile/narrow screens, the table scrolls horizontally.
/// On desktop, it behaves normally.
class CfResponsiveTable extends StatelessWidget {
  const CfResponsiveTable({
    super.key,
    required this.child,
    this.minWidth = 800,
  });

  final Widget child;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final needsScroll = constraints.maxWidth < minWidth;

        if (!needsScroll) {
          return child;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: child,
          ),
        );
      },
    );
  }
}

/// Extension on DataTable for easy responsive wrapping.
extension DataTableResponsive on DataTable {
  /// Wraps this DataTable in a CfResponsiveTable for mobile scrolling.
  Widget responsive({double minWidth = 800}) {
    return CfResponsiveTable(
      minWidth: minWidth,
      child: this,
    );
  }
}

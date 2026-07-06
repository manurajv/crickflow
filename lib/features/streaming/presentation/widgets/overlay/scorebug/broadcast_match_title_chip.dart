import 'package:flutter/material.dart';

import 'scorebug_tokens.dart';

/// Shrink-wrapped match title chip — gold accent bar, rounded panel, shadow.
class BroadcastMatchTitleChip extends StatelessWidget {
  const BroadcastMatchTitleChip({
    super.key,
    required this.title,
    required this.tokens,
    required this.scale,
    this.landscape = true,
  });

  final String title;
  final ScorebugTokens tokens;
  final double scale;
  final bool landscape;

  static TextStyle titleStyle({
    required ScorebugTokens tokens,
    required double scale,
    required bool landscape,
  }) {
    return TextStyle(
      color: tokens.white,
      fontSize: (landscape ? 16 : 13) * scale,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.25,
      height: 1.12,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: IntrinsicWidth(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: (landscape ? 12 : 10) * scale,
                  vertical: 6 * scale,
                ),
                decoration: BoxDecoration(
                  color: tokens.panelBg.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8 * scale),
                  border: Border(
                    left: BorderSide(
                      color: tokens.gold,
                      width: 3 * scale,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10 * scale,
                      offset: Offset(0, 4 * scale),
                    ),
                  ],
                ),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle(
                    tokens: tokens,
                    scale: scale,
                    landscape: landscape,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

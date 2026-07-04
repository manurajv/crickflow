import 'package:flutter/material.dart';

import '../scorebug_tokens.dart';
import 'landscape_scorebug_layout.dart';

/// Ball-by-ball strip above the bowler — all deliveries in the over (incl. extras).
class LandscapeThisOverWidget extends StatelessWidget {
  const LandscapeThisOverWidget({
    super.key,
    required this.labels,
    required this.tokens,
    required this.scale,
  });

  final List<String> labels;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final rowHeight = LandscapeScorebugLayout.secondaryRowHeight(scale);

    if (labels.isEmpty) {
      return SizedBox(height: rowHeight);
    }

    final cells = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      if (i > 0) cells.add(SizedBox(width: 3 * scale));
      cells.add(_BallCell(label: labels[i], tokens: tokens, scale: scale));
    }

    return Container(
      height: rowHeight,
      color: tokens.white.withValues(alpha: 0.97),
      padding: EdgeInsets.only(left: 4 * scale, right: 8 * scale),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: cells,
        ),
      ),
    );
  }
}

class _BallCell extends StatelessWidget {
  const _BallCell({
    required this.label,
    required this.tokens,
    required this.scale,
  });

  final String label;
  final ScorebugTokens tokens;
  final double scale;

  bool get _isBoundary => label == '4' || label == '6';
  bool get _isWicket => label == 'W' || label.contains('W');
  bool get _isDot => label == '0';

  @override
  Widget build(BuildContext context) {
    final bg = _isWicket
        ? tokens.liveRed
        : _isBoundary
            ? tokens.gold
            : tokens.blue;
    final fg = _isBoundary ? tokens.onScore : tokens.white;
    final display = _isDot ? '•' : label;
    final compact = label.length > 2;

    return Container(
      width: (compact ? 22 : 20) * scale,
      height: 18 * scale,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        display,
        style: TextStyle(
          color: fg,
          fontSize: (compact ? 7.5 : 10) * scale,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

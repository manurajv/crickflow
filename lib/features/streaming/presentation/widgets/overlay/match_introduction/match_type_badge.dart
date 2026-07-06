import 'package:flutter/material.dart';

import '../scorebug/scorebug_tokens.dart';

/// Center badge for match stage / type (Semi Final, Match 5, etc.).
class MatchTypeBadge extends StatelessWidget {
  const MatchTypeBadge({
    super.key,
    required this.label,
    required this.tokens,
    required this.scale,
    required this.opacity,
  });

  final String label;
  final ScorebugTokens tokens;
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 22 * scale,
          vertical: 10 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * scale),
          gradient: LinearGradient(
            colors: [
              tokens.panelBg.withValues(alpha: 0.92),
              tokens.blue.withValues(alpha: 0.88),
            ],
          ),
          border: Border.all(
            color: tokens.gold.withValues(alpha: 0.65),
            width: 1.5 * scale,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18 * scale,
              offset: Offset(0, 8 * scale),
            ),
          ],
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tokens.white,
            fontSize: 22 * scale,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

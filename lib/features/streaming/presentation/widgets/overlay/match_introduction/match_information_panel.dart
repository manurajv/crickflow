import 'package:flutter/material.dart';

import '../scorebug/scorebug_tokens.dart';
import 'match_type_badge.dart';

/// Center column — match type, overs, and tournament / individual label.
class MatchInformationPanel extends StatelessWidget {
  const MatchInformationPanel({
    super.key,
    required this.matchTypeLabel,
    required this.oversLabel,
    required this.tournamentLabel,
    required this.tokens,
    required this.scale,
    required this.opacity,
    required this.slideOffset,
  });

  final String matchTypeLabel;
  final String oversLabel;
  final String tournamentLabel;
  final ScorebugTokens tokens;
  final double scale;
  final double opacity;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: slideOffset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MatchTypeBadge(
              label: matchTypeLabel,
              tokens: tokens,
              scale: scale,
              opacity: 1,
            ),
            SizedBox(height: 16 * scale),
            _InfoLine(
              label: oversLabel,
              tokens: tokens,
              scale: scale,
              fontSize: 20,
            ),
            SizedBox(height: 12 * scale),
            Container(
              width: 120 * scale,
              height: 2 * scale,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    tokens.gold,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            SizedBox(height: 12 * scale),
            if (tournamentLabel.trim().isNotEmpty &&
                tournamentLabel.trim().toLowerCase() !=
                    matchTypeLabel.trim().toLowerCase())
              _InfoLine(
                label: tournamentLabel,
                tokens: tokens,
                scale: scale,
                fontSize: 15,
                subdued: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.tokens,
    required this.scale,
    required this.fontSize,
    this.subdued = false,
  });

  final String label;
  final ScorebugTokens tokens;
  final double scale;
  final double fontSize;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    return Text(
      label.toUpperCase(),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: subdued
            ? tokens.white.withValues(alpha: 0.82)
            : tokens.white,
        fontSize: fontSize * scale,
        fontWeight: subdued ? FontWeight.w700 : FontWeight.w800,
        letterSpacing: subdued ? 1.0 : 1.2,
        height: 1.15,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8 * scale,
          ),
        ],
      ),
    );
  }
}

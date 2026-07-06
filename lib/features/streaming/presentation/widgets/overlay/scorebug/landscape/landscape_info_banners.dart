import 'package:flutter/material.dart';

import '../scorebug_tokens.dart';
import 'landscape_scorebug_layout.dart';

/// Floating banner — current run rate at the start of each over.
class LandscapeRunRateBanner extends StatelessWidget {
  const LandscapeRunRateBanner({
    super.key,
    required this.runRate,
    required this.tokens,
    required this.scale,
  });

  final double runRate;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return _TopBannerShell(
      tokens: tokens,
      scale: scale,
      accent: tokens.gold,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CURRENT RUN RATE',
            style: LandscapeScorebugLayout.labelStyle(tokens, scale),
          ),
          SizedBox(width: 10 * scale),
          Text(
            runRate.toStringAsFixed(2),
            style: LandscapeScorebugLayout.valueStyle(tokens, scale).copyWith(
              color: tokens.blue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating banner — partnership milestone (50, 100, 150…).
class LandscapePartnershipBanner extends StatelessWidget {
  const LandscapePartnershipBanner({
    super.key,
    required this.runs,
    required this.balls,
    required this.tokens,
    required this.scale,
  });

  final int runs;
  final int balls;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return _TopBannerShell(
      tokens: tokens,
      scale: scale,
      accent: const Color(0xFF2E7D32),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PARTNERSHIP',
            style: LandscapeScorebugLayout.labelStyle(tokens, scale),
          ),
          SizedBox(width: 10 * scale),
          Text(
            '$runs',
            style: LandscapeScorebugLayout.valueStyle(tokens, scale),
          ),
          Text(
            ' ($balls)',
            style: LandscapeScorebugLayout.labelStyle(tokens, scale).copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.onScore.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating banner — projected score in the late 1st innings (50% up to 20 overs, 20% from 21+).
class LandscapeProjectionBanner extends StatelessWidget {
  const LandscapeProjectionBanner({
    super.key,
    required this.projections,
    required this.tokens,
    required this.scale,
  });

  final List<({double rr, int score, bool isCurrent})> projections;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final labelStyle = LandscapeScorebugLayout.labelStyle(tokens, scale);
    final rrLabelStyle = labelStyle.copyWith(fontSize: 10 * scale);
    final valueStyle = LandscapeScorebugLayout.valueStyle(tokens, scale).copyWith(
      fontSize: 13 * scale,
    );

    return _TopBannerShell(
      tokens: tokens,
      scale: scale,
      accent: tokens.blue,
      fillWidth: true,
      child: Row(
        children: [
          Text('PROJECTED SCORE', style: labelStyle),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final p in projections) ...[
                  if (p.isCurrent)
                    Text('CURR', style: rrLabelStyle)
                  else
                    Text(
                      'RR ${p.rr.toStringAsFixed(0)}',
                      style: rrLabelStyle,
                    ),
                  SizedBox(width: 4 * scale),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7 * scale,
                      vertical: 2 * scale,
                    ),
                    color: tokens.gold,
                    child: Text('${p.score}', style: valueStyle),
                  ),
                  SizedBox(width: 10 * scale),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating banner — runs and balls needed in a chase.
class LandscapeToWinBanner extends StatelessWidget {
  const LandscapeToWinBanner({
    super.key,
    required this.runsNeeded,
    required this.ballsRemaining,
    required this.tokens,
    required this.scale,
  });

  final int runsNeeded;
  final int ballsRemaining;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return _TopBannerShell(
      tokens: tokens,
      scale: scale,
      accent: tokens.liveRed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TO WIN',
            style: LandscapeScorebugLayout.labelStyle(tokens, scale),
          ),
          SizedBox(width: 8 * scale),
          _ValueBox(value: '$runsNeeded', label: 'RUNS', tokens: tokens, scale: scale),
          SizedBox(width: 8 * scale),
          _ValueBox(
            value: '$ballsRemaining',
            label: 'BALLS',
            tokens: tokens,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

/// Floating banner — required run rate after an over is completed.
class LandscapeRequiredRrBanner extends StatelessWidget {
  const LandscapeRequiredRrBanner({
    super.key,
    required this.requiredRunRate,
    required this.tokens,
    required this.scale,
  });

  final double requiredRunRate;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return _TopBannerShell(
      tokens: tokens,
      scale: scale,
      accent: tokens.blue,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'REQUIRED RR',
            style: LandscapeScorebugLayout.labelStyle(tokens, scale),
          ),
          SizedBox(width: 10 * scale),
          Text(
            requiredRunRate.toStringAsFixed(2),
            style: LandscapeScorebugLayout.valueStyle(tokens, scale).copyWith(
              color: tokens.blue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Persistent 2nd-innings fallback chip — "Need X off Y" (target-chip styling).
class LandscapeChaseNeedChip extends StatelessWidget {
  const LandscapeChaseNeedChip({
    super.key,
    required this.runsNeeded,
    required this.ballsRemaining,
    required this.tokens,
    required this.scale,
  });

  final int runsNeeded;
  final int ballsRemaining;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final scoreSize = LandscapeScorebugLayout.totalScoreFontSize(scale);
    final barHeight = LandscapeScorebugLayout.barHeight(scale);
    final labelStyle = LandscapeScorebugLayout.labelStyle(tokens, scale).copyWith(
      fontSize: 11 * scale,
      letterSpacing: 0.8,
      color: tokens.onScore.withValues(alpha: 0.72),
    );
    final scoreStyle = TextStyle(
      color: tokens.onScore,
      fontSize: scoreSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    final connectorStyle = labelStyle.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Container(
      height: barHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.white,
        border: Border(
          left: BorderSide(color: tokens.liveRed, width: 6 * scale),
          right: BorderSide(color: tokens.liveRed, width: 6 * scale),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * scale),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('NEED', style: labelStyle),
                    SizedBox(width: 8 * scale),
                    Text('$runsNeeded', style: scoreStyle),
                    SizedBox(width: 8 * scale),
                    Text('off', style: connectorStyle),
                    SizedBox(width: 8 * scale),
                    Text('$ballsRemaining', style: scoreStyle),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  const _ValueBox({
    required this.value,
    required this.label,
    required this.tokens,
    required this.scale,
  });

  final String value;
  final String label;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 1 * scale),
          color: tokens.blue,
          child: Text(
            value,
            style: TextStyle(
              color: tokens.white,
              fontSize: 10 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: 4 * scale),
        Text(
          label,
          style: LandscapeScorebugLayout.labelStyle(tokens, scale).copyWith(
            fontSize: 8 * scale,
          ),
        ),
      ],
    );
  }
}

class _TopBannerShell extends StatelessWidget {
  const _TopBannerShell({
    required this.tokens,
    required this.scale,
    required this.accent,
    required this.child,
    this.fillWidth = false,
  });

  final ScorebugTokens tokens;
  final double scale;
  final Color accent;
  final Widget child;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final content = fillWidth
        ? Align(alignment: Alignment.centerLeft, child: child)
        : Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: child,
            ),
          );

    return Container(
      width: double.infinity,
      height: LandscapeScorebugLayout.secondaryRowHeight(scale),
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      decoration: BoxDecoration(
        color: tokens.white.withValues(alpha: 0.97),
        border: Border(
          left: BorderSide(color: accent, width: 3 * scale),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: content,
    );
  }
}

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

/// Floating banner — projected score during the last 20% of the first innings.
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
    return _TopBannerShell(
      tokens: tokens,
      scale: scale,
      accent: tokens.blue,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PROJECTED SCORE',
            style: LandscapeScorebugLayout.labelStyle(tokens, scale),
          ),
          SizedBox(width: 8 * scale),
          for (final p in projections) ...[
            if (p.isCurrent)
              Text(
                'CURR',
                style: LandscapeScorebugLayout.labelStyle(tokens, scale).copyWith(
                  fontSize: 8 * scale,
                ),
              )
            else
              Text(
                'RR ${p.rr.toStringAsFixed(0)}',
                style: LandscapeScorebugLayout.labelStyle(tokens, scale).copyWith(
                  fontSize: 8 * scale,
                ),
              ),
            SizedBox(width: 3 * scale),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5 * scale, vertical: 1 * scale),
              color: tokens.gold,
              child: Text(
                '${p.score}',
                style: TextStyle(
                  color: tokens.onScore,
                  fontSize: 9 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 8 * scale),
          ],
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
  });

  final ScorebugTokens tokens;
  final double scale;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}

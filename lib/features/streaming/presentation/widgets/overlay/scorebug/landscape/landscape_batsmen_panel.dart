import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import '../scorebug_helpers.dart';
import '../scorebug_tokens.dart';
import 'landscape_scorebug_layout.dart';

/// Center panel — striker / non-striker with optional chase target.
class LandscapeBatsmenPanel extends StatelessWidget {
  const LandscapeBatsmenPanel({
    super.key,
    required this.overlay,
    required this.tokens,
    required this.scale,
    this.centerTitle,
    this.showTarget = true,
  });

  final OverlayStateModel overlay;
  final ScorebugTokens tokens;
  final double scale;
  final String? centerTitle;
  final bool showTarget;

  @override
  Widget build(BuildContext context) {
    final hasTarget = showTarget && overlay.target != null;
    final reserveTarget = showTarget;
    final targetWidth = LandscapeScorebugLayout.targetChipWidth(scale);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: tokens.navy,
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
      alignment: Alignment.center,
      child: centerTitle != null && centerTitle!.isNotEmpty
          ? _CenterTitle(title: centerTitle!, tokens: tokens, scale: scale)
          : Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _BatterRow(
                          tokens: tokens,
                          scale: scale,
                          name: overlay.strikerName,
                          runs: overlay.strikerRuns,
                          balls: overlay.strikerBalls,
                          onStrike: true,
                        ),
                      ),
                      SizedBox(width: LandscapeScorebugLayout.batterGap(scale)),
                      Flexible(
                        child: _BatterRow(
                          tokens: tokens,
                          scale: scale,
                          name: overlay.nonStrikerName,
                          runs: overlay.nonStrikerRuns,
                          balls: overlay.nonStrikerBalls,
                          onStrike: false,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reserveTarget) ...[
                  SizedBox(width: 10 * scale),
                  SizedBox(
                    width: targetWidth,
                    child: hasTarget
                        ? _TargetChip(
                            target: overlay.target!,
                            tokens: tokens,
                            scale: scale,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
    );
  }
}

class _CenterTitle extends StatelessWidget {
  const _CenterTitle({
    required this.title,
    required this.tokens,
    required this.scale,
  });

  final String title;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: tokens.white,
        fontSize: 15 * scale,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _BatterRow extends StatelessWidget {
  const _BatterRow({
    required this.tokens,
    required this.scale,
    required this.name,
    required this.runs,
    required this.balls,
    required this.onStrike,
  });

  final ScorebugTokens tokens;
  final double scale;
  final String name;
  final int runs;
  final int balls;
  final bool onStrike;

  @override
  Widget build(BuildContext context) {
    final displayName = ScorebugHelpers.shortName(name, max: 12);
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      style: LandscapeScorebugLayout.playerNameStyle(
        tokens,
        scale,
        onStrike: onStrike,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onStrike)
            Padding(
              padding: EdgeInsets.only(right: 6 * scale),
              child: Text(
                '🏏',
                style: TextStyle(fontSize: 13 * scale, height: 1),
              ),
            ),
          Flexible(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8 * scale),
          Text(
            '$runs',
            style: LandscapeScorebugLayout.playerRunsStyle(tokens, scale),
          ),
          SizedBox(width: 5 * scale),
          Text(
            '$balls',
            style: LandscapeScorebugLayout.playerBallsStyle(tokens, scale),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  const _TargetChip({
    required this.target,
    required this.tokens,
    required this.scale,
  });

  final int target;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 4 * scale),
      color: tokens.white,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed, color: tokens.liveRed, size: 12 * scale),
            SizedBox(width: 4 * scale),
            Text(
              '$target',
              style: TextStyle(
                color: tokens.onScore,
                fontSize: 13 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

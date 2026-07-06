import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import '../scorebug_helpers.dart';
import '../scorebug_tokens.dart';
import 'landscape_scorebug_layout.dart';

/// Center panel — fixed left/right batter slots with on-strike indicator only.
class LandscapeBatsmenPanel extends StatefulWidget {
  const LandscapeBatsmenPanel({
    super.key,
    required this.overlay,
    required this.tokens,
    required this.scale,
    this.centerTitle,
    this.showTarget = true,
    this.compact = false,
  });

  final OverlayStateModel overlay;
  final ScorebugTokens tokens;
  final double scale;
  final String? centerTitle;
  final bool showTarget;
  final bool compact;

  @override
  State<LandscapeBatsmenPanel> createState() => _LandscapeBatsmenPanelState();
}

class _LandscapeBatsmenPanelState extends State<LandscapeBatsmenPanel> {
  final _slotTracker = ScorebugBatterSlotTracker();
  String? _trackedMatchId;

  @override
  Widget build(BuildContext context) {
    if (_trackedMatchId != widget.overlay.matchId) {
      _trackedMatchId = widget.overlay.matchId;
      _slotTracker.reset();
    }

    final hasTarget = widget.showTarget && widget.overlay.target != null;
    final slots = _slotTracker.resolve(widget.overlay);
    final horizontalPad = widget.compact ? 12 * widget.scale : 40 * widget.scale;
    final batterGap = widget.compact
        ? 14 * widget.scale
        : LandscapeScorebugLayout.batterGap(widget.scale);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.tokens.navy,
      padding: EdgeInsets.only(
        left: horizontalPad,
        top: 3 * widget.scale,
        bottom: 3 * widget.scale,
        right: hasTarget ? 0 : horizontalPad,
      ),
      alignment: Alignment.center,
      child: widget.centerTitle != null && widget.centerTitle!.isNotEmpty
          ? _CenterTitle(
              title: widget.centerTitle!,
              tokens: widget.tokens,
              scale: widget.scale,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (slots.isNotEmpty) ...[
                        Flexible(
                          flex: 3,
                          child: _BatterRow(
                            tokens: widget.tokens,
                            scale: widget.scale,
                            name: slots[0].name,
                            runs: slots[0].runs,
                            balls: slots[0].balls,
                            onStrike: slots[0].onStrike,
                            compact: widget.compact,
                          ),
                        ),
                        if (slots.length > 1) ...[
                          SizedBox(width: batterGap),
                          Flexible(
                            flex: 3,
                            child: _BatterRow(
                              tokens: widget.tokens,
                              scale: widget.scale,
                              name: slots[1].name,
                              runs: slots[1].runs,
                              balls: slots[1].balls,
                              onStrike: slots[1].onStrike,
                              compact: widget.compact,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (hasTarget)
                  _TargetChip(
                    target: widget.overlay.target!,
                    tokens: widget.tokens,
                    scale: widget.scale,
                  ),
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
    this.compact = false,
  });

  final ScorebugTokens tokens;
  final double scale;
  final String name;
  final int runs;
  final int balls;
  final bool onStrike;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayName = ScorebugHelpers.batterName(name);
    final nameStyle = compact
        ? TextStyle(
            color: onStrike
                ? tokens.white
                : tokens.white.withValues(alpha: 0.88),
            fontSize: (onStrike ? 13.5 : 12.5) * scale,
            fontWeight: onStrike ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0.3,
            height: 1.1,
          )
        : LandscapeScorebugLayout.playerNameStyle(
            tokens,
            scale,
            onStrike: onStrike,
          );
    final runsStyle = compact
        ? TextStyle(
            color: tokens.white,
            fontSize: 14 * scale,
            fontWeight: FontWeight.w900,
            height: 1.1,
          )
        : LandscapeScorebugLayout.playerRunsStyle(tokens, scale);
    final ballsStyle = compact
        ? TextStyle(
            color: tokens.white.withValues(alpha: 0.65),
            fontSize: 11 * scale,
            fontWeight: FontWeight.w500,
            height: 1.1,
          )
        : LandscapeScorebugLayout.playerBallsStyle(tokens, scale);

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      style: nameStyle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onStrike)
            Padding(
              padding: EdgeInsets.only(right: 2 * scale),
              child: Text(
                '🏏',
                style: TextStyle(fontSize: (compact ? 13 : 16) * scale, height: 1),
              ),
            ),
          Flexible(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: (compact ? 5 : 8) * scale),
          Text('$runs', style: runsStyle),
          SizedBox(width: (compact ? 3 : 5) * scale),
          Text('$balls', style: ballsStyle),
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
    final scoreSize = LandscapeScorebugLayout.totalScoreFontSize(scale);

    return Container(
      color: tokens.white,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed, color: tokens.liveRed, size: scoreSize),
          SizedBox(width: 4 * scale),
          Text(
            '$target',
            style: TextStyle(
              color: tokens.onScore,
              fontSize: scoreSize,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

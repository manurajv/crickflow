import 'package:flutter/material.dart';

import '../../../../../../data/models/overlay_state_model.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import 'scorebug_helpers.dart';
import 'scorebug_tokens.dart';

/// Compact 9:16 broadcast scorebug — stacked layout for portrait streams.
class PortraitScorebug extends StatelessWidget {
  const PortraitScorebug({
    super.key,
    required this.overlay,
    required this.theme,
    this.sponsorLogoUrl,
  });

  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final String? sponsorLogoUrl;

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(theme);
    final chase = ScorebugHelpers.chaseLine(overlay);
    final teamAbbr = ScorebugHelpers.teamAbbrev(overlay.battingTeamName);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final scale = (w / 360).clamp(0.85, 1.35);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (theme.showSponsorBanner &&
                (overlay.sponsorText.isNotEmpty || sponsorLogoUrl != null))
              _SponsorChip(
                tokens: tokens,
                text: overlay.sponsorText,
                logoUrl: sponsorLogoUrl,
                scale: scale,
              ),
            _StatusStrip(
              tokens: tokens,
              status: overlay.matchStatus,
              runRate: ScorebugHelpers.runRateLine(overlay),
              chase: chase,
              scale: scale,
            ),
            const SizedBox(height: 4),
            _MainCard(
              tokens: tokens,
              overlay: overlay,
              theme: theme,
              teamAbbr: teamAbbr,
              scale: scale,
            ),
          ],
        );
      },
    );
  }
}

class _SponsorChip extends StatelessWidget {
  const _SponsorChip({
    required this.tokens,
    required this.text,
    required this.logoUrl,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final String text;
  final String? logoUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 6 * scale),
        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
        decoration: BoxDecoration(
          color: tokens.gold,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logoUrl != null && logoUrl!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(right: 6 * scale),
                child: Icon(Icons.image_outlined, size: 14 * scale, color: tokens.onScore),
              ),
            Flexible(
              child: Text(
                text.isNotEmpty ? text : 'CRICKFLOW',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.onScore,
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.tokens,
    required this.status,
    required this.runRate,
    required this.chase,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final String status;
  final String runRate;
  final String? chase;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: tokens.white.withValues(alpha: 0.95),
        border: Border(left: BorderSide(color: tokens.gold, width: 3 * scale)),
      ),
      child: Row(
        children: [
          _LiveDot(tokens: tokens, scale: scale),
          SizedBox(width: 6 * scale),
          Expanded(
            child: Text(
              status.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.onScore,
                fontSize: 9 * scale,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            runRate,
            style: TextStyle(
              color: tokens.blue,
              fontSize: 9 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (chase != null) ...[
            SizedBox(width: 8 * scale),
            Text(
              chase!,
              style: TextStyle(
                color: tokens.onScore,
                fontSize: 9 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.tokens, required this.scale});

  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6 * scale,
      height: 6 * scale,
      decoration: BoxDecoration(
        color: tokens.liveRed,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: tokens.liveRed.withValues(alpha: 0.6),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  const _MainCard({
    required this.tokens,
    required this.overlay,
    required this.theme,
    required this.teamAbbr,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final String teamAbbr;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScoreRow(
            tokens: tokens,
            overlay: overlay,
            teamAbbr: teamAbbr,
            scale: scale,
          ),
          _BatsmenRow(tokens: tokens, overlay: overlay, scale: scale),
          _BowlerRow(
            tokens: tokens,
            overlay: overlay,
            theme: theme,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.tokens,
    required this.overlay,
    required this.teamAbbr,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final OverlayStateModel overlay;
  final String teamAbbr;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Container(
          width: 52 * scale,
          color: tokens.navyDeep,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 6 * scale),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                teamAbbr,
                style: TextStyle(
                  color: tokens.white,
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              if (overlay.battingTeamName.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2 * scale),
                  child: Text(
                    overlay.battingTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tokens.white.withValues(alpha: 0.7),
                      fontSize: 7 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: tokens.white,
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                overlay.scoreDisplay,
                style: TextStyle(
                  color: tokens.onScore,
                  fontSize: 32 * scale,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        Container(
          color: tokens.blue,
          padding: EdgeInsets.symmetric(horizontal: 14 * scale),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'OV',
                style: TextStyle(
                  color: tokens.white.withValues(alpha: 0.75),
                  fontSize: 8 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                overlay.oversDisplay,
                style: TextStyle(
                  color: tokens.white,
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

class _BatsmenRow extends StatelessWidget {
  const _BatsmenRow({
    required this.tokens,
    required this.overlay,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final OverlayStateModel overlay;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.navy,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 7 * scale),
      child: Row(
        children: [
          Expanded(
            child: _BatterCell(
              tokens: tokens,
              name: overlay.strikerName,
              runs: overlay.strikerRuns,
              balls: overlay.strikerBalls,
              onStrike: true,
              scale: scale,
            ),
          ),
          Container(
            width: 1,
            height: 22 * scale,
            color: tokens.white.withValues(alpha: 0.25),
          ),
          Expanded(
            child: _BatterCell(
              tokens: tokens,
              name: overlay.nonStrikerName,
              runs: overlay.nonStrikerRuns,
              balls: overlay.nonStrikerBalls,
              onStrike: false,
              scale: scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatterCell extends StatelessWidget {
  const _BatterCell({
    required this.tokens,
    required this.name,
    required this.runs,
    required this.balls,
    required this.onStrike,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final String name;
  final int runs;
  final int balls;
  final bool onStrike;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onStrike)
          Padding(
            padding: EdgeInsets.only(right: 4 * scale),
            child: Icon(Icons.sports_cricket, color: tokens.gold, size: 12 * scale),
          ),
        Expanded(
          child: Text(
            ScorebugHelpers.shortName(name, max: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onStrike ? tokens.white : tokens.white.withValues(alpha: 0.85),
              fontSize: 11 * scale,
              fontWeight: onStrike ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$runs',
          style: TextStyle(
            color: tokens.gold,
            fontSize: 13 * scale,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(width: 4 * scale),
        Text(
          '($balls)',
          style: TextStyle(
            color: tokens.white.withValues(alpha: 0.65),
            fontSize: 10 * scale,
          ),
        ),
      ],
    );
  }
}

class _BowlerRow extends StatelessWidget {
  const _BowlerRow({
    required this.tokens,
    required this.overlay,
    required this.theme,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.navyDeep,
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
      child: Row(
        children: [
          Text(
            'BOWL',
            style: TextStyle(
              color: tokens.white.withValues(alpha: 0.55),
              fontSize: 8 * scale,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              ScorebugHelpers.bowlerLine(overlay),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.white,
                fontSize: 11 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (theme.showWatermark)
            Icon(
              Icons.sports,
              color: tokens.gold.withValues(alpha: 0.7),
              size: 14 * scale,
            ),
        ],
      ),
    );
  }
}

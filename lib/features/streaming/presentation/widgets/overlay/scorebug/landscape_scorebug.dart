import 'package:flutter/material.dart';

import '../../../../../../data/models/overlay_state_model.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import 'scorebug_helpers.dart';
import 'scorebug_tokens.dart';

/// Full-width 16:9 broadcast scorebug — TV-style bar for landscape streams.
class LandscapeScorebug extends StatelessWidget {
  const LandscapeScorebug({
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
    final teamAbbr = ScorebugHelpers.teamAbbrev(overlay.battingTeamName);
    final chase = ScorebugHelpers.chaseLine(overlay);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final scale = (w / 1280).clamp(0.7, 1.4);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopInfoBar(
              tokens: tokens,
              overlay: overlay,
              chase: chase,
              scale: scale,
            ),
            SizedBox(height: 3 * scale),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _MainScoreBar(
                    tokens: tokens,
                    overlay: overlay,
                    teamAbbr: teamAbbr,
                    scale: scale,
                  ),
                ),
                SizedBox(width: 10 * scale),
                _BowlerModule(
                  tokens: tokens,
                  overlay: overlay,
                  theme: theme,
                  sponsorLogoUrl: sponsorLogoUrl,
                  scale: scale,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TopInfoBar extends StatelessWidget {
  const _TopInfoBar({
    required this.tokens,
    required this.overlay,
    required this.chase,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final OverlayStateModel overlay;
  final String? chase;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 4 * scale),
        decoration: BoxDecoration(
          color: tokens.white.withValues(alpha: 0.96),
          border: Border(
            left: BorderSide(color: tokens.gold, width: 4 * scale),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LiveBadge(tokens: tokens, scale: scale),
            SizedBox(width: 10 * scale),
            if (overlay.battingTeamName.isNotEmpty) ...[
              Text(
                overlay.battingTeamName.toUpperCase(),
                style: TextStyle(
                  color: tokens.onScore,
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              _Divider(scale: scale),
            ],
            Text(
              overlay.matchStatus.toUpperCase(),
              style: TextStyle(
                color: tokens.onScore,
                fontSize: 10 * scale,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            _Divider(scale: scale),
            Text(
              ScorebugHelpers.runRateLine(overlay),
              style: TextStyle(
                color: tokens.blue,
                fontSize: 10 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (chase != null) ...[
              _Divider(scale: scale),
              Text(
                chase!,
                style: TextStyle(
                  color: tokens.onScore,
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.tokens, required this.scale});

  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
      color: tokens.liveRed,
      child: Text(
        'LIVE',
        style: TextStyle(
          color: tokens.white,
          fontSize: 8 * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      child: Text(
        '|',
        style: TextStyle(
          color: Colors.black26,
          fontSize: 10 * scale,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}

class _MainScoreBar extends StatelessWidget {
  const _MainScoreBar({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TeamBlock(tokens: tokens, teamAbbr: teamAbbr, scale: scale),
            _ScoreBlock(tokens: tokens, overlay: overlay, scale: scale),
            _OversBlock(tokens: tokens, overlay: overlay, scale: scale),
            Expanded(
              child: _BatsmenBlock(tokens: tokens, overlay: overlay, scale: scale),
            ),
            if (overlay.target != null)
              _TargetBlock(tokens: tokens, target: overlay.target!, scale: scale),
          ],
        ),
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.tokens,
    required this.teamAbbr,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final String teamAbbr;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38 * scale,
          color: tokens.white,
          alignment: Alignment.center,
          child: Icon(Icons.sports_cricket, color: tokens.navyDeep, size: 20 * scale),
        ),
        Container(
          width: 48 * scale,
          color: tokens.navyDeep,
          alignment: Alignment.center,
          child: Text(
            teamAbbr,
            style: TextStyle(
              color: tokens.white,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({
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
      constraints: BoxConstraints(minWidth: 88 * scale),
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tokens.white,
            tokens.white.withValues(alpha: 0.92),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        overlay.scoreDisplay,
        style: TextStyle(
          color: tokens.onScore,
          fontSize: 28 * scale,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _OversBlock extends StatelessWidget {
  const _OversBlock({
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
      width: 64 * scale,
      color: tokens.blue,
      alignment: Alignment.center,
      child: Text(
        overlay.oversDisplay,
        style: TextStyle(
          color: tokens.white,
          fontSize: 20 * scale,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BatsmenBlock extends StatelessWidget {
  const _BatsmenBlock({
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
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            _BatterLabel(
              tokens: tokens,
              name: overlay.strikerName,
              runs: overlay.strikerRuns,
              balls: overlay.strikerBalls,
              onStrike: true,
              scale: scale,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12 * scale),
              child: Text(
                '/',
                style: TextStyle(
                  color: tokens.white.withValues(alpha: 0.4),
                  fontSize: 16 * scale,
                ),
              ),
            ),
            _BatterLabel(
              tokens: tokens,
              name: overlay.nonStrikerName,
              runs: overlay.nonStrikerRuns,
              balls: overlay.nonStrikerBalls,
              onStrike: false,
              scale: scale,
            ),
          ],
        ),
      ),
    );
  }
}

class _BatterLabel extends StatelessWidget {
  const _BatterLabel({
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
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onStrike)
          Padding(
            padding: EdgeInsets.only(right: 5 * scale),
            child: Icon(Icons.sports_cricket, color: tokens.gold, size: 13 * scale),
          ),
        Text(
          ScorebugHelpers.shortName(name, max: 14),
          style: TextStyle(
            color: onStrike ? tokens.white : tokens.white.withValues(alpha: 0.88),
            fontSize: 13 * scale,
            fontWeight: onStrike ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(width: 8 * scale),
        Text(
          '$runs',
          style: TextStyle(
            color: tokens.gold,
            fontSize: 14 * scale,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(width: 4 * scale),
        Text(
          '$balls',
          style: TextStyle(
            color: tokens.white.withValues(alpha: 0.6),
            fontSize: 11 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TargetBlock extends StatelessWidget {
  const _TargetBlock({
    required this.tokens,
    required this.target,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final int target;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72 * scale,
      color: tokens.white,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed, color: tokens.liveRed, size: 14 * scale),
          SizedBox(width: 4 * scale),
          Text(
            '$target',
            style: TextStyle(
              color: tokens.onScore,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BowlerModule extends StatelessWidget {
  const _BowlerModule({
    required this.tokens,
    required this.overlay,
    required this.theme,
    required this.sponsorLogoUrl,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final String? sponsorLogoUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 22 * scale,
                color: tokens.white.withValues(alpha: 0.95),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                child: Text(
                  overlay.battingTeamName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.onScore.withValues(alpha: 0.7),
                    fontSize: 8 * scale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 36 * scale,
                      color: tokens.white,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.sports,
                        color: tokens.navyDeep,
                        size: 18 * scale,
                      ),
                    ),
                    Container(
                      constraints: BoxConstraints(minWidth: 140 * scale),
                      color: tokens.navyDeep,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 8 * scale,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        ScorebugHelpers.bowlerLine(overlay),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.white,
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (theme.showSponsorBanner) ...[
          SizedBox(width: 6 * scale),
          _SponsorTile(
            tokens: tokens,
            text: overlay.sponsorText,
            scale: scale,
          ),
        ],
      ],
    );
  }
}

class _SponsorTile extends StatelessWidget {
  const _SponsorTile({
    required this.tokens,
    required this.text,
    required this.scale,
  });

  final ScorebugTokens tokens;
  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44 * scale,
      height: 44 * scale,
      color: tokens.gold,
      alignment: Alignment.center,
      child: text.isNotEmpty
          ? Padding(
              padding: EdgeInsets.all(4 * scale),
              child: FittedBox(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: tokens.onScore,
                    fontSize: 7 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          : Icon(Icons.sports_cricket, color: tokens.onScore, size: 22 * scale),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import '../scorebug_tokens.dart';
import 'landscape_powerplay_badge.dart';
import 'landscape_scorebug_layout.dart';
import 'landscape_team_logo.dart';

/// Left scorebug panel — team logo, abbreviation, score, overs, powerplay.
class LandscapeBattingPanel extends StatelessWidget {
  const LandscapeBattingPanel({
    super.key,
    required this.overlay,
    required this.tokens,
    required this.scale,
    required this.teamAbbr,
    this.teamLogoUrl,
    this.powerplayBadge,
  });

  final OverlayStateModel overlay;
  final ScorebugTokens tokens;
  final double scale;
  final String teamAbbr;
  final String? teamLogoUrl;
  final String? powerplayBadge;

  @override
  Widget build(BuildContext context) {
    final logoSize = LandscapeScorebugLayout.barHeight(scale);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LandscapeTeamLogo(
          name: overlay.battingTeamName,
          logoUrl: teamLogoUrl,
          size: logoSize,
          tokens: tokens,
        ),
        Container(
          width: 46 * scale,
          color: tokens.navyDeep,
          alignment: Alignment.center,
          child: Text(
            teamAbbr,
            style: TextStyle(
              color: tokens.white,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          constraints: BoxConstraints(minWidth: 78 * scale),
          padding: EdgeInsets.symmetric(horizontal: 14 * scale),
          color: tokens.white,
          alignment: Alignment.center,
          child: Text(
            overlay.scoreDisplay,
            style: TextStyle(
              color: tokens.onScore,
              fontSize: 24 * scale,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        Container(
          width: 52 * scale,
          color: tokens.blue,
          alignment: Alignment.center,
          child: Text(
            overlay.oversDisplay,
            style: TextStyle(
              color: tokens.white,
              fontSize: 17 * scale,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (powerplayBadge != null && powerplayBadge!.isNotEmpty)
          LandscapePowerplayBadge(
            label: powerplayBadge!,
            tokens: tokens,
            scale: scale,
          ),
      ],
    );
  }
}

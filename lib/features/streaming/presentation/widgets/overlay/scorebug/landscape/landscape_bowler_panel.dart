import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import '../scorebug_helpers.dart';
import '../scorebug_tokens.dart';
import 'landscape_scorebug_layout.dart';
import 'landscape_team_logo.dart';

/// Right panel — bowling team logo, name (left), figures (right).
class LandscapeBowlerPanel extends StatelessWidget {
  const LandscapeBowlerPanel({
    super.key,
    required this.overlay,
    required this.tokens,
    required this.scale,
    this.bowlingTeamName = '',
    this.bowlingTeamLogoUrl,
  });

  final OverlayStateModel overlay;
  final ScorebugTokens tokens;
  final double scale;
  final String bowlingTeamName;
  final String? bowlingTeamLogoUrl;

  @override
  Widget build(BuildContext context) {
    final logoSize = LandscapeScorebugLayout.barHeight(scale);
    final name = ScorebugHelpers.bowlerName(overlay);
    final figures = ScorebugHelpers.bowlerFigures(overlay);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LandscapeTeamLogo(
          name: bowlingTeamName,
          logoUrl: bowlingTeamLogoUrl,
          size: logoSize,
          tokens: tokens,
        ),
        Expanded(
          child: Container(
            color: tokens.navyDeep,
            padding: EdgeInsets.symmetric(horizontal: 8 * scale),
            alignment: Alignment.center,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LandscapeScorebugLayout.bowlerNameStyle(tokens, scale),
                  ),
                ),
                SizedBox(width: 6 * scale),
                Text(
                  figures,
                  style: LandscapeScorebugLayout.bowlerFiguresStyle(tokens, scale),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

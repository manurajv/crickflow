import 'package:flutter/material.dart';

import '../../../../../../../data/models/overlay_state_model.dart';
import '../scorebug_helpers.dart';
import '../scorebug_tokens.dart';
import 'landscape_scorebug_layout.dart';
import 'landscape_team_logo.dart';
import 'landscape_this_over_widget.dart';

/// Right panel — bowling team logo, name, figures, optional inline this-over strip.
class LandscapeBowlerPanel extends StatelessWidget {
  const LandscapeBowlerPanel({
    super.key,
    required this.overlay,
    required this.tokens,
    required this.scale,
    this.bowlingTeamName = '',
    this.bowlingTeamLogoUrl,
    this.thisOverLabels = const [],
    this.inlineThisOver = false,
  });

  final OverlayStateModel overlay;
  final ScorebugTokens tokens;
  final double scale;
  final String bowlingTeamName;
  final String? bowlingTeamLogoUrl;
  final List<String> thisOverLabels;
  final bool inlineThisOver;

  @override
  Widget build(BuildContext context) {
    final logoSize = LandscapeScorebugLayout.barHeight(scale);
    final name = ScorebugHelpers.bowlerName(overlay);
    final figures = ScorebugHelpers.bowlerFigures(overlay);

    final details = Container(
      color: tokens.panelBg,
      padding: EdgeInsets.symmetric(
        horizontal: 8 * scale,
        vertical: inlineThisOver ? 4 * scale : 0,
      ),
      alignment: Alignment.center,
      child: inlineThisOver
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LandscapeScorebugLayout.bowlerNameStyle(
                          tokens,
                          scale,
                        ),
                      ),
                    ),
                    SizedBox(width: 6 * scale),
                    Text(
                      figures,
                      style: LandscapeScorebugLayout.bowlerFiguresStyle(
                        tokens,
                        scale,
                      ),
                    ),
                  ],
                ),
                if (thisOverLabels.isNotEmpty) ...[
                  SizedBox(height: 4 * scale),
                  ThisOverBallStrip(
                    labels: thisOverLabels,
                    tokens: tokens,
                    scale: scale,
                  ),
                ],
              ],
            )
          : Row(
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
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LandscapeTeamLogo(
            name: bowlingTeamName,
            logoUrl: bowlingTeamLogoUrl,
            size: logoSize,
            tokens: tokens,
          ),
          Expanded(child: details),
        ],
      ),
    );
  }
}

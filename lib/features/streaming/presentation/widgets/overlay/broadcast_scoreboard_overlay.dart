import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/cricket_math.dart';
import '../../../../../data/models/overlay_state_model.dart';
import '../../../data/models/stream_overlay_theme.dart';
import '../../../domain/streaming_enums.dart';

/// TV-style scorebug rendered over the camera preview.
class BroadcastScoreboardOverlay extends StatelessWidget {
  const BroadcastScoreboardOverlay({
    super.key,
    required this.overlay,
    required this.theme,
    this.tournamentLogoUrl,
    this.sponsorLogoUrl,
  });

  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final String? tournamentLogoUrl;
  final String? sponsorLogoUrl;

  @override
  Widget build(BuildContext context) {
    if (theme.layout == StreamOverlayLayout.minimal) {
      return _minimalBug();
    }
    if (theme.layout == StreamOverlayLayout.compact || theme.compactMode) {
      return _compactBug();
    }
    return _fullBug();
  }

  Widget _fullBug() {
    final primary = Color(theme.primaryColor);
    final secondary = Color(theme.secondaryColor);
    final radius = theme.roundedCorners ? 12.0 : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (theme.showSponsorBanner && overlay.sponsorText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.black54,
            child: Text(
              overlay.sponsorText,
              textAlign: TextAlign.center,
              style: TextStyle(color: secondary, fontWeight: FontWeight.bold),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: theme.opacity),
                AppColors.primaryBlue.withValues(alpha: theme.opacity * 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: secondary, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (theme.showWatermark)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Opacity(
                        opacity: theme.watermarkOpacity,
                        child: Icon(Icons.sports_cricket,
                            color: secondary, size: theme.logoSize * 0.5),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      overlay.battingTeamName,
                      style: TextStyle(
                        color: secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    color: AppColors.liveIndicator,
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${overlay.scoreDisplay} (${overlay.oversDisplay} ov)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _rateLine(),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const Divider(color: AppColors.border, height: 16),
              Row(
                children: [
                  Expanded(
                    child: _batter(
                      '*${overlay.strikerName}',
                      overlay.strikerRuns,
                      overlay.strikerBalls,
                      true,
                    ),
                  ),
                  Expanded(
                    child: _batter(
                      overlay.nonStrikerName,
                      overlay.nonStrikerRuns,
                      overlay.nonStrikerBalls,
                      false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${overlay.bowlerName} '
                '${CricketMath.formatOvers(overlay.bowlerBalls, overlay.ballsPerOver)}-'
                '${overlay.bowlerRuns}-${overlay.bowlerWickets}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactBug() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(theme.primaryColor).withValues(alpha: theme.opacity),
        borderRadius:
            BorderRadius.circular(theme.roundedCorners ? 8 : 0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${overlay.battingTeamName} ${overlay.scoreDisplay} (${overlay.oversDisplay})',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            'RR ${overlay.runRate.toStringAsFixed(2)}',
            style: TextStyle(color: Color(theme.secondaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _minimalBug() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.black.withValues(alpha: 0.55),
      child: Text(
        '${overlay.scoreDisplay} (${overlay.oversDisplay})',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  String _rateLine() {
    final parts = <String>['RR ${overlay.runRate.toStringAsFixed(2)}'];
    if (overlay.requiredRunRate != null) {
      parts.add('RRR ${overlay.requiredRunRate!.toStringAsFixed(2)}');
    }
    if (overlay.target != null) {
      parts.add('Target ${overlay.target}');
    }
    return parts.join(' • ');
  }

  Widget _batter(String name, int runs, int balls, bool onStrike) {
    return Text(
      '${onStrike ? '*' : ''}$name $runs($balls)',
      style: TextStyle(
        color: onStrike ? Colors.white : Colors.white70,
        fontSize: 13,
        fontWeight: onStrike ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

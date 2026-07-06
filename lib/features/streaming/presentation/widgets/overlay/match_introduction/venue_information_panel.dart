import 'package:flutter/material.dart';

import '../../../../data/models/match_introduction_snapshot.dart';
import '../scorebug/scorebug_tokens.dart';

/// Bottom glass panel — venue, location, and schedule when available.
class VenueInformationPanel extends StatelessWidget {
  const VenueInformationPanel({
    super.key,
    required this.snapshot,
    required this.tokens,
    required this.scale,
    required this.opacity,
    required this.slideOffset,
  });

  final MatchIntroductionSnapshot snapshot;
  final ScorebugTokens tokens;
  final double scale;
  final double opacity;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasVenueSection &&
        !snapshot.hasLocationDetails &&
        !snapshot.hasSchedule) {
      return const SizedBox.shrink();
    }

    final locationParts = [
      if (snapshot.city != null && snapshot.city!.isNotEmpty) snapshot.city!,
      if (snapshot.stateProvince != null && snapshot.stateProvince!.isNotEmpty)
        snapshot.stateProvince!,
      if (snapshot.country != null && snapshot.country!.isNotEmpty)
        snapshot.country!,
    ];

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: slideOffset,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 48 * scale),
          padding: EdgeInsets.symmetric(
            horizontal: 24 * scale,
            vertical: 16 * scale,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16 * scale),
            gradient: LinearGradient(
              colors: [
                tokens.panelBg.withValues(alpha: 0.78),
                tokens.navyDeep.withValues(alpha: 0.72),
              ],
            ),
            border: Border.all(
              color: tokens.white.withValues(alpha: 0.12),
              width: 1 * scale,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20 * scale,
                offset: Offset(0, 8 * scale),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (snapshot.hasVenueSection) ...[
                Text(
                  snapshot.venue!.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.white,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                if (locationParts.isNotEmpty || snapshot.hasSchedule)
                  SizedBox(height: 8 * scale),
              ],
              if (locationParts.isNotEmpty)
                Text(
                  locationParts.join(' · '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.white.withValues(alpha: 0.82),
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              if (snapshot.hasSchedule) ...[
                if (locationParts.isNotEmpty || snapshot.hasVenueSection)
                  SizedBox(height: 8 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (snapshot.dateLabel != null &&
                        snapshot.dateLabel!.isNotEmpty) ...[
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13 * scale,
                        color: tokens.gold,
                      ),
                      SizedBox(width: 6 * scale),
                      Text(
                        snapshot.dateLabel!,
                        style: TextStyle(
                          color: tokens.white.withValues(alpha: 0.9),
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (snapshot.dateLabel != null &&
                        snapshot.dateLabel!.isNotEmpty &&
                        snapshot.timeLabel != null &&
                        snapshot.timeLabel!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                        child: Text(
                          '•',
                          style: TextStyle(
                            color: tokens.gold.withValues(alpha: 0.8),
                            fontSize: 12 * scale,
                          ),
                        ),
                      ),
                    if (snapshot.timeLabel != null &&
                        snapshot.timeLabel!.isNotEmpty) ...[
                      Icon(
                        Icons.schedule_outlined,
                        size: 13 * scale,
                        color: tokens.gold,
                      ),
                      SizedBox(width: 6 * scale),
                      Text(
                        snapshot.timeLabel!,
                        style: TextStyle(
                          color: tokens.white.withValues(alpha: 0.9),
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

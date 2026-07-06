import 'package:flutter/material.dart';

import '../../../../data/models/match_introduction_snapshot.dart';
import '../scorebug/landscape/landscape_team_logo.dart';
import '../scorebug/scorebug_tokens.dart';

/// TV-style bottom information band — team logos/names, match type, venue.
class MatchIntroductionBottomBand extends StatelessWidget {
  const MatchIntroductionBottomBand({
    super.key,
    required this.snapshot,
    required this.tokens,
    required this.scale,
    required this.opacity,
    required this.slideOffset,
    this.compact = false,
  });

  final MatchIntroductionSnapshot snapshot;
  final ScorebugTokens tokens;
  final double scale;
  final double opacity;
  final Offset slideOffset;
  final bool compact;

  String? get _venueLine {
    if (!snapshot.hasVenueSection) return null;
    final parts = <String>[snapshot.venue!.trim()];
    if (snapshot.city != null && snapshot.city!.isNotEmpty) {
      parts.add(snapshot.city!);
    } else if (snapshot.stateProvince != null &&
        snapshot.stateProvince!.isNotEmpty) {
      parts.add(snapshot.stateProvince!);
    }
    if (snapshot.country != null && snapshot.country!.isNotEmpty) {
      parts.add(snapshot.country!);
    }
    return 'LIVE FROM ${parts.join(', ')}';
  }

  String get _matchTypeLine {
    final type = snapshot.matchTypeLabel.trim();
    final overs = snapshot.oversLabel.trim();
    if (type.isEmpty) return overs.toUpperCase();
    if (overs.isEmpty) return type.toUpperCase();
    return '${overs.toUpperCase()} · ${type.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final venueLine = _venueLine;
    final logoSize = (compact ? 28 : 36) * scale;
    final teamFontSize = (compact ? 9.5 : 12) * scale;
    final matchFontSize = (compact ? 11.5 : 14) * scale;
    final venueFontSize = (compact ? 9 : 10.5) * scale;
    final horizontalPad = (compact ? 12 : 14) * scale;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: slideOffset,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10 * scale)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: tokens.white,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: (compact ? 6 : 8) * scale,
                  ),
                  child: Row(
                    children: [
                      LandscapeTeamLogo(
                        name: snapshot.teamA.teamName,
                        logoUrl: snapshot.teamA.teamLogoUrl,
                        size: logoSize,
                        tokens: tokens,
                      ),
                      SizedBox(width: 8 * scale),
                      Expanded(
                        flex: 5,
                        child: Text(
                          snapshot.teamA.teamName.toUpperCase(),
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.onScore,
                            fontSize: teamFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            height: 1.1,
                          ),
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        flex: 5,
                        child: Text(
                          snapshot.teamB.teamName.toUpperCase(),
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: tokens.onScore,
                            fontSize: teamFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            height: 1.1,
                          ),
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      LandscapeTeamLogo(
                        name: snapshot.teamB.teamName,
                        logoUrl: snapshot.teamB.teamLogoUrl,
                        size: logoSize,
                        tokens: tokens,
                      ),
                    ],
                  ),
                ),
              ),
              ColoredBox(
                color: tokens.panelBg,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: (compact ? 7 : 9) * scale,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _matchTypeLine,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.white,
                          fontSize: matchFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          height: 1.15,
                        ),
                      ),
                      if (snapshot.tournamentLabel.trim().isNotEmpty) ...[
                        SizedBox(height: 3 * scale),
                        Text(
                          snapshot.tournamentLabel.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.gold,
                            fontSize: (compact ? 9 : 10.5) * scale,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (venueLine != null ||
                  snapshot.hasSchedule ||
                  snapshot.hasLocationDetails)
                ColoredBox(
                  color: tokens.navyDeep,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPad,
                      vertical: (compact ? 6 : 8) * scale,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (venueLine != null)
                          Text(
                            venueLine.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: compact ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.white,
                              fontSize: venueFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        if (snapshot.hasSchedule) ...[
                          if (venueLine != null) SizedBox(height: 3 * scale),
                          Text(
                            _scheduleLine(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: tokens.white.withValues(alpha: 0.82),
                              fontSize: venueFontSize * 0.92,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _scheduleLine() {
    final parts = <String>[];
    if (snapshot.dateLabel != null && snapshot.dateLabel!.isNotEmpty) {
      parts.add(snapshot.dateLabel!);
    }
    if (snapshot.timeLabel != null && snapshot.timeLabel!.isNotEmpty) {
      parts.add(snapshot.timeLabel!);
    }
    return parts.join(' · ');
  }
}

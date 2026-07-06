import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Frozen presentation data for the pre-match broadcast introduction overlay.
class MatchIntroductionSnapshot extends Equatable {
  const MatchIntroductionSnapshot({
    required this.matchTitle,
    required this.matchTypeLabel,
    required this.oversLabel,
    required this.tournamentLabel,
    required this.teamA,
    required this.teamB,
    this.venue,
    this.city,
    this.stateProvince,
    this.country,
    this.dateLabel,
    this.timeLabel,
    this.crickflowLogoUrl = '',
  });

  final String matchTitle;
  final String matchTypeLabel;
  final String oversLabel;
  final String tournamentLabel;
  final MatchIntroductionTeamSide teamA;
  final MatchIntroductionTeamSide teamB;
  final String? venue;
  final String? city;
  final String? stateProvince;
  final String? country;
  final String? dateLabel;
  final String? timeLabel;
  final String crickflowLogoUrl;

  bool get hasVenueSection =>
      venue != null && venue!.trim().isNotEmpty;

  bool get hasLocationDetails =>
      (city != null && city!.isNotEmpty) ||
      (stateProvince != null && stateProvince!.isNotEmpty) ||
      (country != null && country!.isNotEmpty);

  bool get hasSchedule =>
      (dateLabel != null && dateLabel!.isNotEmpty) ||
      (timeLabel != null && timeLabel!.isNotEmpty);

  static const empty = MatchIntroductionSnapshot(
    matchTitle: '',
    matchTypeLabel: '',
    oversLabel: '',
    tournamentLabel: '',
    teamA: MatchIntroductionTeamSide(teamName: 'Team A'),
    teamB: MatchIntroductionTeamSide(teamName: 'Team B'),
  );

  @override
  List<Object?> get props => [
        matchTitle,
        matchTypeLabel,
        oversLabel,
        tournamentLabel,
        teamA,
        teamB,
        venue,
        city,
        stateProvince,
        country,
        dateLabel,
        timeLabel,
        crickflowLogoUrl,
      ];
}

class MatchIntroductionTeamSide extends Equatable {
  const MatchIntroductionTeamSide({
    required this.teamName,
    this.teamLogoUrl,
    this.captainName,
    this.captainPhotoUrl,
    this.accentColor = const Color(0xFF1A5FA8),
  });

  final String teamName;
  final String? teamLogoUrl;
  final String? captainName;
  final String? captainPhotoUrl;
  final Color accentColor;

  bool get hasCaptainPhoto =>
      captainPhotoUrl != null && captainPhotoUrl!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        teamName,
        teamLogoUrl,
        captainName,
        captainPhotoUrl,
        accentColor,
      ];
}

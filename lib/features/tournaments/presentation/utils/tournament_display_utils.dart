import '../../../../core/constants/enums.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../data/models/tournament_model.dart';

export '../../../../core/utils/tournament_match_stage_utils.dart';

String tournamentFormatLabel(TournamentFormat format) => switch (format) {
      TournamentFormat.league => 'League',
      TournamentFormat.knockout => 'Knockout',
      TournamentFormat.leagueKnockout => 'League + Knockout',
      TournamentFormat.custom => 'Custom',
    };

String tournamentOfficialRoleLabel(TournamentOfficialRole role) => switch (role) {
      TournamentOfficialRole.scorer => 'Scorers',
      TournamentOfficialRole.umpire => 'Umpires',
      TournamentOfficialRole.commentator => 'Commentators',
      TournamentOfficialRole.streamer => 'Streamers',
      TournamentOfficialRole.photographer => 'Photographers',
      TournamentOfficialRole.videographer => 'Videographers',
    };

/// Non-empty ground names configured on the tournament.
List<String> tournamentGroundNames(TournamentModel tournament) =>
    tournament.grounds.map((g) => g.trim()).where((g) => g.isNotEmpty).toList();

String tournamentOfficialRoleSingular(TournamentOfficialRole role) =>
    switch (role) {
      TournamentOfficialRole.scorer => 'Scorer',
      TournamentOfficialRole.umpire => 'Umpire',
      TournamentOfficialRole.commentator => 'Commentator',
      TournamentOfficialRole.streamer => 'Streamer',
      TournamentOfficialRole.photographer => 'Photographer',
      TournamentOfficialRole.videographer => 'Videographer',
    };

String tournamentStatusLabel(TournamentStatus status) => switch (status) {
      TournamentStatus.draft => 'Draft',
      TournamentStatus.upcoming => 'Upcoming',
      TournamentStatus.live => 'Live',
      TournamentStatus.completed => 'Completed',
      TournamentStatus.cancelled => 'Cancelled',
    };

String tournamentRoleLabel(TournamentRole role) => switch (role) {
      TournamentRole.owner => 'Owner',
      TournamentRole.admin => 'Admin',
      TournamentRole.scorer => 'Scorer',
      TournamentRole.viewer => 'Viewer',
    };

String cricketBallTypeLabel(CricketBallType type) => switch (type) {
      CricketBallType.leather => 'Leather',
      CricketBallType.tennis => 'Tennis',
      CricketBallType.indoor => 'Indoor',
    };

String pitchTypeLabel(PitchType type) => switch (type) {
      PitchType.rough => 'Rough',
      PitchType.cement => 'Cement',
      PitchType.turf => 'Turf',
      PitchType.astroturf => 'Astroturf',
      PitchType.matting => 'Matting',
    };

String winningPrizeTypeLabel(WinningPrizeType type) => switch (type) {
      WinningPrizeType.cash => 'Cash',
      WinningPrizeType.trophies => 'Trophies',
      WinningPrizeType.both => 'Cash & Trophies',
    };

String tournamentCricketMatchTypeLabel(CricketMatchType type) => switch (type) {
      CricketMatchType.limitedOvers => 'Limited Overs',
      CricketMatchType.indoor => 'Indoor',
      CricketMatchType.testMatch => 'Test Match',
    };

/// Entry fee using tournament country / stored budget currency (not hardcoded INR).
String formatEntryFee(
  double? fee, {
  String? countryOrCode,
  String? currencyCode,
}) {
  return formatCurrencyAmount(
    fee,
    countryOrCode: countryOrCode,
    currencyCode: currencyCode,
  );
}

String formatPrizePool(TournamentModel tournament) {
  final prize = tournament.winningPrize?.trim();
  if (prize != null && prize.isNotEmpty) return prize;
  return winningPrizeTypeLabel(tournament.setupMeta.winningPrizeType);
}

/// Resolves currency for a tournament (setup meta, else location country).
String tournamentCurrencyCode(TournamentModel tournament) {
  final stored = tournament.setupMeta.budgetCurrencyCode.trim();
  if (stored.isNotEmpty) return stored;
  return currencyCodeForCountry(tournament.location.country);
}

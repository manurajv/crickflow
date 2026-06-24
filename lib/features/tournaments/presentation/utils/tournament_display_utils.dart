import '../../../../core/constants/enums.dart';
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

String tournamentOfficialRoleSingular(TournamentOfficialRole role) =>
    switch (role) {
      TournamentOfficialRole.scorer => 'Scorer',
      TournamentOfficialRole.umpire => 'Umpire',
      TournamentOfficialRole.commentator => 'Commentator',
      TournamentOfficialRole.streamer => 'Streamer',
      TournamentOfficialRole.photographer => 'Photographer',
      TournamentOfficialRole.videographer => 'Videographer',
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

String formatEntryFee(double? fee) {
  if (fee == null) return '—';
  if (fee == fee.roundToDouble()) return '₹${fee.toInt()}';
  return '₹${fee.toStringAsFixed(0)}';
}

String formatPrizePool(TournamentModel tournament) {
  final prize = tournament.winningPrize?.trim();
  if (prize != null && prize.isNotEmpty) return prize;
  return winningPrizeTypeLabel(tournament.setupMeta.winningPrizeType);
}

import '../../core/constants/app_constants.dart';
import '../../core/utils/overs_formatter.dart';
import '../../data/models/player_model.dart';
import 'stat_grid.dart';

enum PlayerStatViewMode { batting, bowling, fielding }

List<StatCellData> playerStatCells(
  PlayerStatsModel stats,
  PlayerStatViewMode mode, {
  int? ballsPerOver,
  double? bowlingActualOvers,
}) {
  final bpo = ballsPerOver ?? AppConstants.defaultBallsPerOver;
  final notOuts = (stats.inningsPlayed - stats.dismissals).clamp(0, 999);
  final battingAvg = stats.dismissals == 0
      ? stats.runs.toDouble()
      : stats.runs / stats.dismissals;
  final sr = stats.ballsFaced == 0
      ? 0.0
      : (stats.runs / stats.ballsFaced) * 100;
  final overs = bowlingActualOvers != null && bowlingActualOvers > 0
      ? _formatDecimalOvers(bowlingActualOvers, bpo)
      : OversFormatter.formatOvers(stats.oversBowledBalls, bpo);
  final actualOvers = bowlingActualOvers ??
      OversFormatter.calculateOvers(stats.oversBowledBalls, bpo);
  final econ = actualOvers == 0
      ? 0.0
      : OversFormatter.economyFromDecimalOvers(stats.runsConceded, actualOvers);
  final bowlAvg = stats.wickets == 0 ? 0.0 : stats.runsConceded / stats.wickets;

  return switch (mode) {
    PlayerStatViewMode.batting => [
      StatCellData(value: '${stats.matchesPlayed}', label: 'Mat'),
      StatCellData(value: '${stats.inningsPlayed}', label: 'Inns'),
      StatCellData(value: '$notOuts', label: 'NO'),
      StatCellData(value: '${stats.runs}', label: 'Runs'),
      StatCellData(
        value: stats.highScore > 0 ? '${stats.highScore}' : '—',
        label: 'HS',
      ),
      StatCellData(value: battingAvg.toStringAsFixed(2), label: 'Avg'),
      StatCellData(value: sr.toStringAsFixed(2), label: 'SR'),
      StatCellData(value: '${stats.thirties}', label: '30s'),
      StatCellData(value: '${stats.fifties}', label: '50s'),
      StatCellData(value: '${stats.hundreds}', label: '100s'),
      StatCellData(value: '${stats.fours}', label: '4s'),
      StatCellData(value: '${stats.sixes}', label: '6s'),
      StatCellData(value: '${stats.ducks}', label: 'Ducks'),
    ],
    PlayerStatViewMode.bowling => [
      StatCellData(value: '${stats.matchesPlayed}', label: 'Mat'),
      StatCellData(value: overs, label: 'Ov'),
      StatCellData(value: '0', label: 'Mdns'),
      StatCellData(value: '${stats.runsConceded}', label: 'Runs'),
      StatCellData(value: '${stats.wickets}', label: 'Wkts'),
      StatCellData(value: econ.toStringAsFixed(2), label: 'Econ'),
      StatCellData(value: bowlAvg.toStringAsFixed(2), label: 'Avg'),
      StatCellData(value: '${stats.threeWickets}', label: '3W'),
      StatCellData(value: '${stats.fiveWickets}', label: '5W'),
    ],
    PlayerStatViewMode.fielding => [
      StatCellData(value: '${stats.catches}', label: 'Catches'),
      StatCellData(value: '${stats.runOuts}', label: 'Run outs'),
      StatCellData(value: '${stats.stumpings}', label: 'Stumpings'),
      StatCellData(
        value: '${stats.catches + stats.runOuts + stats.stumpings}',
        label: 'Total',
      ),
      StatCellData(value: '${stats.matchesPlayed}', label: 'Mat'),
      StatCellData(value: '${stats.dismissals}', label: 'Dismissals'),
    ],
  };
}

String _formatDecimalOvers(double decimalOvers, int ballsPerOver) {
  final bpo = OversFormatter.normalizeBallsPerOver(ballsPerOver);
  final whole = decimalOvers.floor();
  final remainder =
      ((decimalOvers - whole) * bpo).round().clamp(0, bpo - 1);
  return '$whole.$remainder';
}

import '../../core/utils/cricket_math.dart';
import '../../data/models/player_model.dart';
import 'stat_grid.dart';

enum PlayerStatViewMode { batting, bowling, fielding }

List<StatCellData> playerStatCells(
  PlayerStatsModel stats,
  PlayerStatViewMode mode,
) {
  final notOuts = (stats.inningsPlayed - stats.dismissals).clamp(0, 999);
  final avg = CricketMath.battingAverage(stats.runs, stats.dismissals);
  final sr = CricketMath.strikeRate(stats.runs, stats.ballsFaced);
  final overs = CricketMath.formatOvers(stats.oversBowledBalls, 6);
  final econ = CricketMath.economyRate(stats.runsConceded, stats.oversBowledBalls, 6);
  final bowlAvg = CricketMath.bowlingAverage(stats.runsConceded, stats.wickets);

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
      StatCellData(value: avg.toStringAsFixed(2), label: 'Avg'),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../data/models/player_model.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/widgets/stat_grid.dart';

enum _StatsMode { batting, bowling, fielding }

class MyCricketStatsTab extends ConsumerStatefulWidget {
  const MyCricketStatsTab({super.key});

  @override
  ConsumerState<MyCricketStatsTab> createState() => _MyCricketStatsTabState();
}

class _MyCricketStatsTabState extends ConsumerState<MyCricketStatsTab> {
  _StatsMode _mode = _StatsMode.batting;

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(myPlayerProvider);

    return playerAsync.when(
      data: (player) {
        if (player == null) {
          return _noPlayer(context);
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPlayerProvider),
          child: ListView(
            padding: AppDimens.listPadding,
            children: [
              _PlayerHeader(player: player),
              const SizedBox(height: AppDimens.spaceSm),
              _analyzeBanner(context, player),
              const SizedBox(height: AppDimens.spaceMd),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _modeChip('Batting', _StatsMode.batting),
                    const SizedBox(width: AppDimens.spaceXs),
                    _modeChip('Bowling', _StatsMode.bowling),
                    const SizedBox(width: AppDimens.spaceXs),
                    _modeChip('Fielding', _StatsMode.fielding),
                  ],
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Row(
                children: [
                  Text('Overall', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/players/${player.id}'),
                    child: const Text('Full profile'),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              StatGrid(cells: _cellsForMode(player, _mode)),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Stats update when matches you play are completed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _noPlayer(BuildContext context) {
    return ListView(
      padding: AppDimens.listPadding,
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.person_outline,
          size: 56,
          color: AppColors.primaryBlueLight.withValues(alpha: 0.5),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          'No player profile linked',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Switch to Member mode in Profile to create your player stats.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppDimens.spaceLg),
        Center(
          child: FilledButton(
            onPressed: () => context.push('/profile'),
            child: const Text('Open Profile'),
          ),
        ),
      ],
    );
  }

  Widget _PlayerHeader({required PlayerModel player}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primaryBlue,
          backgroundImage: player.photoUrl != null
              ? CachedNetworkImageProvider(player.photoUrl!)
              : null,
          child: player.photoUrl == null
              ? Text(
                  player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (player.role.isNotEmpty)
                Text(
                  player.role,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              if (player.location.displayLabel.isNotEmpty)
                Text(
                  player.location.displayLabel,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _analyzeBanner(BuildContext context, PlayerModel player) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: AppDimens.cardRadius,
      child: ListTile(
        dense: true,
        title: const Text('Want to improve your stats?'),
        trailing: FilledButton(
          onPressed: () => context.push('/players/${player.id}'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: const Text('Analyze'),
        ),
      ),
    );
  }

  Widget _modeChip(String label, _StatsMode mode) {
    final selected = _mode == mode;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _mode = mode),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.4),
      checkmarkColor: AppColors.gold,
      labelStyle: TextStyle(
        color: selected ? AppColors.gold : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  List<StatCellData> _cellsForMode(PlayerModel player, _StatsMode mode) {
    final s = player.stats;
    final notOuts = (s.inningsPlayed - s.dismissals).clamp(0, 999);
    final avg = CricketMath.battingAverage(s.runs, s.dismissals);
    final sr = CricketMath.strikeRate(s.runs, s.ballsFaced);
    final overs = CricketMath.formatOvers(s.oversBowledBalls, 6);
    final econ = CricketMath.economyRate(s.runsConceded, s.oversBowledBalls, 6);
    final bowlAvg = CricketMath.bowlingAverage(s.runsConceded, s.wickets);

    return switch (mode) {
      _StatsMode.batting => [
        StatCellData(value: '${s.matchesPlayed}', label: 'Mat'),
        StatCellData(value: '${s.inningsPlayed}', label: 'Inns'),
        StatCellData(value: '$notOuts', label: 'NO'),
        StatCellData(value: '${s.runs}', label: 'Runs'),
        StatCellData(
          value: s.highScore > 0 ? '${s.highScore}' : '—',
          label: 'HS',
        ),
        StatCellData(value: avg.toStringAsFixed(2), label: 'Avg'),
        StatCellData(value: sr.toStringAsFixed(2), label: 'SR'),
        StatCellData(value: '${s.thirties}', label: '30s'),
        StatCellData(value: '${s.fifties}', label: '50s'),
        StatCellData(value: '${s.hundreds}', label: '100s'),
        StatCellData(value: '${s.fours}', label: '4s'),
        StatCellData(value: '${s.sixes}', label: '6s'),
        StatCellData(value: '${s.ducks}', label: 'Ducks'),
      ],
      _StatsMode.bowling => [
        StatCellData(value: '${s.matchesPlayed}', label: 'Mat'),
        StatCellData(value: overs, label: 'Ov'),
        StatCellData(value: '0', label: 'Mdns'),
        StatCellData(value: '${s.runsConceded}', label: 'Runs'),
        StatCellData(value: '${s.wickets}', label: 'Wkts'),
        StatCellData(value: econ.toStringAsFixed(2), label: 'Econ'),
        StatCellData(value: bowlAvg.toStringAsFixed(2), label: 'Avg'),
        StatCellData(value: '${s.threeWickets}', label: '3W'),
        StatCellData(value: '${s.fiveWickets}', label: '5W'),
      ],
      _StatsMode.fielding => [
        StatCellData(value: '${s.catches}', label: 'Catches'),
        StatCellData(value: '${s.runOuts}', label: 'Run outs'),
        StatCellData(value: '${s.stumpings}', label: 'Stumpings'),
        StatCellData(
          value: '${s.catches + s.runOuts + s.stumpings}',
          label: 'Total',
        ),
        StatCellData(value: '${s.matchesPlayed}', label: 'Mat'),
        StatCellData(value: '${s.dismissals}', label: 'Dismissals'),
      ],
    };
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/player_model.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/my_player_stats_breakdown_provider.dart';
import '../../../../shared/widgets/player_stat_cells.dart';
import '../../../../shared/widgets/stat_grid.dart';
import '../widgets/my_cricket_action_banner.dart';

class MyCricketStatsTab extends ConsumerStatefulWidget {
  const MyCricketStatsTab({super.key});

  @override
  ConsumerState<MyCricketStatsTab> createState() => _MyCricketStatsTabState();
}

class _MyCricketStatsTabState extends ConsumerState<MyCricketStatsTab> {
  PlayerStatViewMode _mode = PlayerStatViewMode.batting;

  @override
  Widget build(BuildContext context) {
    final breakdownAsync = ref.watch(myPlayerStatsBreakdownProvider);

    return breakdownAsync.when(
      data: (breakdown) {
        if (breakdown == null) {
          return _noPlayer(context);
        }
        final player = ref.watch(myPlayerProvider).value!;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myPlayerProvider);
            ref.invalidate(myPlayerStatsBreakdownProvider);
          },
          child: ListView(
            padding: AppDimens.listPadding,
            children: [
              _PlayerHeader(player: player),
              const SizedBox(height: AppDimens.spaceSm),
              MyCricketActionBanner(
                inset: false,
                title: 'Want to improve your stats?',
                actionLabel: 'Analyze',
                onAction: () => context.push('/players/${player.id}'),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              _modeChips(context),
              const SizedBox(height: AppDimens.spaceMd),
              _sectionHeader(context, 'Overall'),
              StatGrid(
                cells: playerStatCells(breakdown.overall, _mode),
              ),
              ...breakdown.typedSections.expand(
                (section) => [
                  const SizedBox(height: AppDimens.spaceLg),
                  _sectionHeader(context, section.title),
                  StatGrid(
                    cells: playerStatCells(
                      section.stats,
                      _mode,
                      ballsPerOver: section.ballsPerOver,
                      bowlingActualOvers: section.bowlingActualOvers,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Type sections appear after you complete a match in that format. '
                'Set ball type when creating a match (Leather / Tennis / Indoor).',
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

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (title == 'Overall') ...[
            const Spacer(),
            TextButton(
              onPressed: () {
                final p = ref.read(myPlayerProvider).valueOrNull;
                if (p != null) context.push('/players/${p.id}');
              },
              child: const Text('Full profile'),
            ),
          ],
        ],
      ),
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

  Widget _modeChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _modeChip(context, 'Batting', PlayerStatViewMode.batting),
          const SizedBox(width: AppDimens.spaceXs),
          _modeChip(context, 'Bowling', PlayerStatViewMode.bowling),
          const SizedBox(width: AppDimens.spaceXs),
          _modeChip(context, 'Fielding', PlayerStatViewMode.fielding),
        ],
      ),
    );
  }

  Widget _modeChip(BuildContext context, String label, PlayerStatViewMode mode) {
    final cf = context.cf;
    final selected = _mode == mode;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _mode = mode),
      selectedColor: cf.accent.withValues(alpha: 0.15),
      checkmarkColor: cf.accent,
      labelStyle: TextStyle(
        color: selected ? cf.accent : cf.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

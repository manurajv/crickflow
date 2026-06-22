import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/player_model.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../shared/providers/my_player_stats_breakdown_provider.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../../shared/widgets/player_stat_cells.dart';
import '../../../../shared/widgets/stat_grid.dart';
import '../../../my_cricket/presentation/widgets/my_cricket_action_banner.dart';
import '../widgets/captain_stats_section.dart';
import '../widgets/profile_match_filter_button.dart';

class ProfileStatsTab extends ConsumerStatefulWidget {
  const ProfileStatsTab({
    super.key,
    required this.player,
    required this.matches,
    required this.captainStats,
  });

  final PlayerModel player;
  final List<MatchModel> matches;
  final CaptainStatsSnapshot captainStats;

  @override
  ConsumerState<ProfileStatsTab> createState() => _ProfileStatsTabState();
}

class _ProfileStatsTabState extends ConsumerState<ProfileStatsTab> {
  _StatsMode _mode = _StatsMode.batting;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final filters = ref.watch(profileMatchFiltersProvider);
    final service = ref.watch(playerTypedStatsServiceProvider);
    final breakdown = buildProfileFilteredStatsBreakdown(
      player: widget.player,
      participatedMatches: widget.matches,
      filters: filters,
      service: service,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myCricketProfileProvider);
      },
      child: ListView(
        padding: AppDimens.listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          MyCricketActionBanner(
            inset: false,
            title: 'Deep dive into your game',
            actionLabel: 'Analyze',
            onAction: () =>
                context.push('/players/${widget.player.id}/analysis'),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _modeChips(context, cf),
          const SizedBox(height: AppDimens.spaceMd),
          if (_mode == _StatsMode.captain)
            CaptainStatsSection(stats: widget.captainStats)
          else ...[
            _overallHeader(context),
            StatGrid(
              cells: playerStatCells(
                breakdown.overall,
                _mode.asViewMode,
              ),
            ),
            ...breakdown.typedSections.expand(
              (section) => [
                const SizedBox(height: AppDimens.spaceLg),
                _sectionHeader(context, section.title),
                StatGrid(
                  cells: playerStatCells(
                    section.stats,
                    _mode.asViewMode,
                    ballsPerOver: section.ballsPerOver,
                    bowlingActualOvers: section.bowlingActualOvers,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _overallHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Overall',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ProfileMatchFilterButton(
            matches: widget.matches,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _modeChips(BuildContext context, CfColors cf) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, cf, 'Batting', _StatsMode.batting),
          const SizedBox(width: AppDimens.spaceXs),
          _chip(context, cf, 'Bowling', _StatsMode.bowling),
          const SizedBox(width: AppDimens.spaceXs),
          _chip(context, cf, 'Fielding', _StatsMode.fielding),
          const SizedBox(width: AppDimens.spaceXs),
          _chip(context, cf, 'Captain', _StatsMode.captain),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    CfColors cf,
    String label,
    _StatsMode mode,
  ) {
    final selected = _mode == mode;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _mode = mode),
      selectedColor: cf.accent.withValues(alpha: 0.15),
      checkmarkColor: cf.accent,
    );
  }
}

enum _StatsMode { batting, bowling, fielding, captain }

extension on _StatsMode {
  PlayerStatViewMode get asViewMode => switch (this) {
        _StatsMode.batting => PlayerStatViewMode.batting,
        _StatsMode.bowling => PlayerStatViewMode.bowling,
        _StatsMode.fielding => PlayerStatViewMode.fielding,
        _StatsMode.captain => PlayerStatViewMode.fielding,
      };
}

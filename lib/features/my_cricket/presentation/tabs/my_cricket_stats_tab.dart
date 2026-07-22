import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/player_model.dart';
import '../../../../domain/services/captain_stats_service.dart';
import '../../../../domain/services/profile_match_filter_service.dart';
import '../../../../features/my_cricket/my_cricket_filters.dart';
import '../../../../features/my_cricket_profile/presentation/widgets/captain_stats_section.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/my_player_stats_breakdown_provider.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/player_stat_cells.dart';
import '../../../../shared/widgets/stat_grid.dart';
import '../widgets/my_cricket_action_banner.dart';
import '../widgets/my_cricket_guest_sign_in_prompt.dart';

class MyCricketStatsTab extends ConsumerStatefulWidget {
  const MyCricketStatsTab({super.key});

  @override
  ConsumerState<MyCricketStatsTab> createState() => _MyCricketStatsTabState();
}

class _MyCricketStatsTabState extends ConsumerState<MyCricketStatsTab> {
  _StatsMode _mode = _StatsMode.batting;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return const MyCricketGuestSignInPrompt(
        title: 'Sign in to view your stats',
        subtitle:
            'Sign in with a CrickFlow account to track batting, bowling, '
            'fielding, and captain stats from your matches.',
      );
    }

    final playerAsync = ref.watch(myPlayerProvider);
    final matchesAsync = ref.watch(matchesProvider);
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();

    return playerAsync.when(
      data: (player) {
        if (player == null) {
          return _noPlayer(context);
        }

        return matchesAsync.when(
          data: (matches) {
            final participated = matches
                .where(
                  (m) => userParticipatedInMatch(
                    m,
                    uid: uid,
                    player: player,
                    userTeamIds: userTeamIds,
                  ),
                )
                .toList();
            final filters = ref.watch(profileMatchFiltersProvider);
            final service = ref.watch(playerTypedStatsServiceProvider);
            final breakdown = buildProfileFilteredStatsBreakdown(
              player: player,
              participatedMatches: participated,
              filters: filters,
              service: service,
            );
            final filteredMatches =
                filterProfileMatches(participated, filters);
            final captainStats = const CaptainStatsService().compute(
              playerId: player.id,
              completedMatches: filteredMatches
                  .where((m) => m.status == MatchStatus.completed)
                  .toList(),
            );

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myPlayerProvider);
                ref.invalidate(matchesProvider);
              },
              child: ListView(
                padding: AppDimens.listPadding,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _PlayerHeader(player: player),
                  const SizedBox(height: AppDimens.spaceSm),
                  MyCricketActionBanner(
                    inset: false,
                    title: 'Want to improve your stats?',
                    actionLabel: 'Analyze',
                    onAction: () =>
                        context.push('/players/${player.id}/analysis'),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  _modeChips(context),
                  const SizedBox(height: AppDimens.spaceMd),
                  if (_mode == _StatsMode.captain)
                    CaptainStatsSection(stats: captainStats)
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
                    const SizedBox(height: AppDimens.spaceLg),
                    Text(
                      'Type sections appear after you complete a match in that format. '
                      'Set ball type when creating a match (Leather / Tennis / Indoor).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _overallHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(
        'Overall',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
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
    final cf = context.cf;
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
      labelStyle: TextStyle(
        color: selected ? cf.accent : cf.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
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

import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../data/models/fantasy_entry_model.dart';
import '../../../data/models/fantasy_league_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';

class FantasyLeagueScreen extends ConsumerStatefulWidget {
  const FantasyLeagueScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<FantasyLeagueScreen> createState() =>
      _FantasyLeagueScreenState();
}

class _FantasyLeagueScreenState extends ConsumerState<FantasyLeagueScreen> {
  bool _refreshingPoints = false;

  @override
  Widget build(BuildContext context) {
    final leagueAsync = ref.watch(fantasyLeagueProvider(widget.leagueId));
    final leaderboardAsync =
        ref.watch(fantasyLeaderboardProvider(widget.leagueId));
    final uid = ref.watch(authStateProvider).value?.uid;

    return leagueAsync.when(
      data: (league) {
        if (league == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('League not found')),
          );
        }

        ref.listen(ballEventsProvider(league.matchId), (prev, next) {
          next.whenData((events) => _syncPoints(league, events));
        });

        final myEntryAsync = uid == null
            ? const AsyncValue.data(null)
            : ref.watch(fantasyMyEntryProvider((widget.leagueId, uid)));

        return Scaffold(
          appBar: AppBar(title: Text(league.name)),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(fantasyLeaderboardProvider(widget.leagueId));
              final events =
                  await ref.read(matchRepositoryProvider).getBallEvents(
                        league.matchId,
                      );
              await ref.read(fantasyRepositoryProvider).refreshLeaguePoints(
                    league: league,
                    ballEvents: events,
                  );
            },
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              children: [
                _leagueHeader(context, league),
                const SizedBox(height: AppDimens.spaceMd),
                myEntryAsync.when(
                  data: (entry) => _mySquadCard(context, league, entry),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Leaderboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_refreshingPoints) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                leaderboardAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No squads yet. Share the join code!'),
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          ListTile(
                            leading: CircleAvatar(
                              child: Text('${i + 1}'),
                            ),
                            title: Text(entries[i].displayName),
                            subtitle: Text(
                              entries[i].playerIds.isEmpty
                                  ? 'Squad not set'
                                  : '${entries[i].playerIds.length} players',
                            ),
                            trailing: Text(
                              entries[i].totalPoints.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }

  Future<void> _syncPoints(
    FantasyLeagueModel league,
    List<BallEventModel> events,
  ) async {
    if (_refreshingPoints) return;
    setState(() => _refreshingPoints = true);
    try {
      await ref.read(fantasyRepositoryProvider).refreshLeaguePoints(
            league: league,
            ballEvents: events,
          );
    } finally {
      if (mounted) setState(() => _refreshingPoints = false);
    }
  }

  Widget _leagueHeader(BuildContext context, FantasyLeagueModel league) {
    final uid = ref.read(authStateProvider).value?.uid;
    final isCreator = uid == league.createdBy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              league.matchTitle,
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Join code: '),
                Text(
                  league.joinCode,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        letterSpacing: 2,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: league.joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Join code copied')),
                    );
                  },
                ),
              ],
            ),
            Chip(
              label: Text(league.status.name.toUpperCase()),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 12),
            CfButton(
              label: 'View match',
              icon: Icons.sports_cricket,
              isOutlined: true,
              onPressed: () => context.push('/match/${league.matchId}'),
            ),
            if (isCreator) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (league.isOpen)
                    TextButton(
                      onPressed: () => _setStatus(league, FantasyLeagueStatus.locked),
                      child: const Text('Lock squads'),
                    ),
                  if (league.status == FantasyLeagueStatus.locked)
                    TextButton(
                      onPressed: () => _setStatus(league, FantasyLeagueStatus.open),
                      child: const Text('Reopen squads'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mySquadCard(
    BuildContext context,
    FantasyLeagueModel league,
    FantasyEntryModel? entry,
  ) {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Card(
      color: AppColors.primaryBlue.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My squad',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (entry == null)
              CfButton(
                label: 'Join this league',
                icon: Icons.person_add,
                onPressed: () async {
                  final profile =
                      ref.read(currentUserProfileProvider).valueOrNull;
                  await ref.read(fantasyRepositoryProvider).joinLeague(
                        league: league,
                        userId: uid,
                        displayName: profile?.displayName ?? 'Player',
                      );
                  ref.invalidate(
                    fantasyMyEntryProvider((widget.leagueId, uid)),
                  );
                },
              )
            else ...[
              Text(
                entry.playerIds.isEmpty
                    ? 'Pick ${league.squadSize} players from the match squads.'
                    : '${entry.playerIds.length}/${league.squadSize} players · ${entry.totalPoints.toStringAsFixed(1)} pts',
              ),
              const SizedBox(height: 12),
              CfButton(
                label: entry.playerIds.isEmpty ? 'Build squad' : 'Edit squad',
                icon: Icons.groups,
                onPressed: league.isOpen
                    ? () => context.push('/fantasy/${league.id}/squad')
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(
    FantasyLeagueModel league,
    FantasyLeagueStatus status,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    try {
      await ref.read(fantasyRepositoryProvider).setLeagueStatus(
            leagueId: league.id,
            status: status,
            requesterId: uid,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

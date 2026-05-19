import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/cricket_math.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Players')),
      body: teamsAsync.when(
        data: (teams) {
          if (teams.isEmpty) {
            return const Center(
              child: Text('Create a team first, then add players from team settings.'),
            );
          }
          return ListView(
            children: teams.map((team) {
              final playersAsync = ref.watch(teamPlayersProvider(team.id));
              return playersAsync.when(
                data: (players) => Card(
                  margin: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(team.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('${players.length} players'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/teams/${team.id}'),
                      ),
                      if (players.isEmpty)
                        const ListTile(title: Text('No players added'))
                      else
                        ...players.map((p) {
                          final sr = CricketMath.strikeRate(
                            p.stats.runs,
                            p.stats.ballsFaced,
                          );
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryBlue,
                              child: Text(
                                p.jerseyNumber?.toString() ??
                                    (p.name.isNotEmpty
                                        ? p.name[0].toUpperCase()
                                        : '?'),
                              ),
                            ),
                            title: Text(p.name),
                            subtitle: Text(
                              '${p.battingStyle} • ${p.location.city}',
                            ),
                            trailing: Text(
                              '${p.stats.runs} runs\nSR ${sr.toStringAsFixed(1)}',
                              textAlign: TextAlign.right,
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

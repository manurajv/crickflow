import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/player_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import 'widgets/add_player_sheet.dart';
import 'widgets/team_join_banner.dart';

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(_teamProvider(teamId));
    final playersAsync = ref.watch(teamPlayersProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Invite to team',
            onPressed: () {
              final team = teamAsync.valueOrNull;
              if (team != null) _shareTeamInvite(team);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPlayer(context, ref),
        child: const Icon(Icons.person_add),
      ),
      body: teamAsync.when(
        data: (team) {
          if (team == null) return const Center(child: Text('Team not found'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _uploadLogo(context, ref, team),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryBlue,
                      backgroundImage: team.logoUrl != null
                          ? CachedNetworkImageProvider(team.logoUrl!)
                          : null,
                      child: team.logoUrl == null
                          ? Text(
                              team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(team.name, style: const TextStyle(fontSize: 22)),
                        Text(team.location.displayLabel),
                        TextButton.icon(
                          onPressed: () => _uploadLogo(context, ref, team),
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text('Upload logo'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statChip('Played', '${team.stats.matchesPlayed}'),
                  _statChip('Won', '${team.stats.matchesWon}'),
                  _statChip('Points', '${team.stats.points}'),
                ],
              ),
              const Divider(height: 32),
              const Text('Squad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              playersAsync.when(
                data: (players) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TeamJoinBanner(
                        team: team,
                        teamId: teamId,
                        squad: players,
                      ),
                      if (players.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No players yet. Tap + to add.'),
                        )
                      else
                        ...players
                        .map(
                          (p) => ListTile(
                            leading: GestureDetector(
                              onTap: () => _uploadPlayerPhoto(context, ref, p),
                              child: CircleAvatar(
                                backgroundImage: p.photoUrl != null
                                    ? CachedNetworkImageProvider(p.photoUrl!)
                                    : null,
                                child: p.photoUrl == null
                                    ? Text(
                                        p.jerseyNumber?.toString() ??
                                            (p.name.isNotEmpty
                                                ? p.name[0].toUpperCase()
                                                : '?'),
                                      )
                                    : null,
                              ),
                            ),
                            title: Text(p.name),
                            subtitle: Text(
                              [
                                if (p.role.isNotEmpty) p.role,
                                if (p.battingStyle.isNotEmpty) p.battingStyle,
                              ].join(' • '),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.camera_alt, size: 20),
                              tooltip: 'Upload photo',
                              onPressed: () =>
                                  _uploadPlayerPhoto(context, ref, p),
                            ),
                          ),
                        )
                        .toList(),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Future<void> _uploadPlayerPhoto(
    BuildContext context,
    WidgetRef ref,
    PlayerModel player,
  ) async {
    try {
      final url = await ref
          .read(storageServiceProvider)
          .pickAndUploadPlayerPhoto(player.id);
      if (url == null) return;

      final updated = player.copyWith(photoUrl: url);
      await ref.read(playerRepositoryProvider).updatePlayer(updated);
      ref.invalidate(teamPlayersProvider(teamId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo updated for ${player.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
        );
      }
    }
  }

  Future<void> _uploadLogo(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
  ) async {
    try {
      final url = await ref.read(storageServiceProvider).pickAndUploadTeamLogo(team.id);
      if (url == null) return;
      final updated = TeamModel(
        id: team.id,
        name: team.name,
        logoUrl: url,
        captainId: team.captainId,
        viceCaptainId: team.viceCaptainId,
        coachName: team.coachName,
        playerIds: team.playerIds,
        location: team.location,
        stats: team.stats,
        badgeIds: team.badgeIds,
        createdBy: team.createdBy,
        createdAt: team.createdAt,
      );
      await ref.read(teamRepositoryProvider).updateTeam(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Widget _statChip(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.gold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _shareTeamInvite(TeamModel team) {
    final link = DeepLinkUtils.teamUri(team.id);
    Share.share(
      'Join ${team.name} on CrickFlow.\n'
      'Open: $link',
    );
  }

  void _showAddPlayer(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddPlayerSheet(teamId: teamId),
    );
  }
}

final _teamProvider = StreamProvider.family<TeamModel?, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).watchTeam(teamId);
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../data/models/player_model.dart';
import '../../../data/models/team_model.dart';
import '../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import '../../wagon_wheel/presentation/widgets/wagon_wheel_embedded_section.dart';
import '../../../shared/widgets/cf_underlined_field.dart';
import 'widgets/team_join_banner.dart';
import 'widgets/team_logo_picker.dart';
import 'widgets/team_player_tile.dart';

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(_teamProvider(teamId));
    final playersAsync = ref.watch(teamPlayersProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        title: teamAsync.when(
          data: (t) => Text(t?.name ?? 'Team'),
          loading: () => const Text('Team'),
          error: (_, __) => const Text('Team'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit team',
            onPressed: () {
              final team = teamAsync.valueOrNull;
              if (team != null) _showEditTeam(context, ref, team);
            },
          ),
        ],
      ),
      body: teamAsync.when(
        data: (team) {
          if (team == null) return const Center(child: Text('Team not found'));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: AppColors.primaryBlue.withValues(alpha: 0.35),
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined, color: AppColors.gold),
                  title: const Text('Squad banners'),
                  subtitle: const Text('Share match highlights with your team'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Squad banners — coming soon')),
                    );
                  },
                ),
              ),
              Padding(
                padding: AppDimens.listPadding,
                child: WagonWheelEmbeddedSection(
                  title: 'Team wagon wheel',
                  fullViewTitle: '${team.name} — scoring',
                  baseFilter: WagonWheelFilter(teamId: teamId),
                  showWhenEmpty: false,
                ),
              ),
              Expanded(
                child: playersAsync.when(
                  data: (players) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(_teamProvider(teamId));
                        ref.invalidate(teamPlayersProvider(teamId));
                      },
                      child: ListView(
                        padding: const EdgeInsets.only(
                          top: AppDimens.spaceSm,
                          bottom: AppDimens.spaceXl,
                        ),
                        children: [
                          TeamJoinBanner(
                            team: team,
                            teamId: teamId,
                            squad: players,
                          ),
                          if (players.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(AppDimens.spaceXl),
                              child: Center(
                                child: Text(
                                  'No players yet.\nTap Add player below.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            ...players.map(
                              (p) => TeamPlayerTile(
                                player: p,
                                team: team,
                                isCaptain: team.captainId == p.id,
                                onPhotoTap: () =>
                                    _uploadPlayerPhoto(context, ref, p),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      bottomNavigationBar: teamAsync.maybeWhen(
        data: (team) {
          if (team == null) return null;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceSm,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showTeamProfile(context, ref, team),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          context.push('/teams/$teamId/add-players'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        backgroundColor: AppColors.primaryBlue,
                      ),
                      child: const Text(
                        'Add player',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  void _showTeamProfile(BuildContext context, WidgetRef ref, TeamModel team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TeamLogoPicker(
                  logoUrl: team.logoUrl,
                  teamName: team.name,
                  size: 96,
                  onTap: () {
                    Navigator.pop(ctx);
                    _uploadLogo(context, ref, team);
                  },
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                team.name,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              Text(
                team.location.displayLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(ctx, 'Played', '${team.stats.matchesPlayed}'),
                  _stat(ctx, 'Won', '${team.stats.matchesWon}'),
                  _stat(ctx, 'Points', '${team.stats.points}'),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),
              OutlinedButton.icon(
                onPressed: () {
                  final link = DeepLinkUtils.httpsTeamUri(team.id).toString();
                  Share.share('Join ${team.name} on CrickFlow.\n$link');
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share team invite'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
        ),
        Text(label),
      ],
    );
  }

  Future<void> _showEditTeam(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
  ) async {
    final nameController = TextEditingController(text: team.name);
    final cityController = TextEditingController(text: team.location.city);
    final captainController = TextEditingController(text: team.coachName ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: AppDimens.spaceLg,
          right: AppDimens.spaceLg,
          top: AppDimens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit team', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppDimens.spaceLg),
            CfUnderlinedField(
              controller: nameController,
              label: 'Team name',
              required: true,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            CfUnderlinedField(
              controller: cityController,
              label: 'City / town',
              required: true,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            CfUnderlinedField(
              controller: captainController,
              label: 'Captain name',
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save'),
            ),
            const SizedBox(height: AppDimens.spaceLg),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final updated = TeamModel(
      id: team.id,
      name: nameController.text.trim(),
      logoUrl: team.logoUrl,
      captainId: team.captainId,
      viceCaptainId: team.viceCaptainId,
      coachName: captainController.text.trim().isEmpty
          ? null
          : captainController.text.trim(),
      playerIds: team.playerIds,
      location: team.location.copyWith(city: cityController.text.trim()),
      stats: team.stats,
      badgeIds: team.badgeIds,
      createdBy: team.createdBy,
      createdAt: team.createdAt,
    );
    await ref.read(teamRepositoryProvider).updateTeam(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team updated')),
      );
    }
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
      final url =
          await ref.read(storageServiceProvider).pickAndUploadTeamLogo(team.id);
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
}

final _teamProvider = StreamProvider.family<TeamModel?, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).watchTeam(teamId);
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import 'widgets/team_method_card.dart';

/// Reference-style ways to add players to a team.
class TeamAddPlayersScreen extends ConsumerWidget {
  const TeamAddPlayersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(_teamProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        title: teamAsync.when(
          data: (t) => Text(t == null ? 'Add players' : 'Add players to ${t.name}'),
          loading: () => const Text('Add players'),
          error: (_, __) => const Text('Add players'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/teams/$teamId/add-players/directory'),
          ),
        ],
      ),
      body: teamAsync.when(
        data: (team) {
          if (team == null) {
            return const Center(child: Text('Team not found'));
          }
          final link = DeepLinkUtils.httpsTeamUri(team.id).toString();
          return ListView(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
            children: [
              TeamMethodCard(
                icon: Icons.link,
                title: 'Team link',
                subtitle: 'Easiest way to add players.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Share this link with the captain and let them add '
                      'players directly to the team.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    SelectableText(
                      link,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _share(link, team),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: AppColors.primaryBlueLight,
                              side: const BorderSide(color: AppColors.primaryBlue),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceMd),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _shareWhatsApp(link, team),
                            icon: const Icon(Icons.chat),
                            label: const Text('WhatsApp'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              backgroundColor: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TeamMethodCard(
                icon: Icons.dialpad,
                title: 'Add via phone number or email',
                subtitle: 'Best for adding 1 or 2 players quickly.',
                onTap: () => context.push('/teams/$teamId/add-players/quick'),
                trailing: const Icon(Icons.chevron_right),
              ),
              TeamMethodCard(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Add from player directory',
                subtitle: 'Search registered players or create a walk-in profile.',
                onTap: () => context.push('/teams/$teamId/add-players/directory'),
                trailing: const Icon(Icons.chevron_right),
              ),
              TeamMethodCard(
                icon: Icons.qr_code_2,
                title: 'Team QR code',
                subtitle: 'Scan and add players directly via QR code.',
                onTap: () => _showQrDialog(context, link, team),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  void _share(String link, TeamModel team) {
    Share.share(
      'Join ${team.name} on CrickFlow.\n$link',
    );
  }

  Future<void> _shareWhatsApp(String link, TeamModel team) async {
    final text = Uri.encodeComponent(
      'Join ${team.name} on CrickFlow: $link',
    );
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Share.share('Join ${team.name} on CrickFlow.\n$link');
    }
  }

  void _showQrDialog(BuildContext context, String link, TeamModel team) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${team.name} invite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2,
              size: 120,
              color: AppColors.gold.withValues(alpha: 0.85),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            const Text(
              'Share the team link below. Players can open it in CrickFlow to join.',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            SelectableText(link, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              _share(link, team);
              Navigator.pop(ctx);
            },
            child: const Text('Share link'),
          ),
        ],
      ),
    );
  }
}

final _teamProvider = StreamProvider.family<TeamModel?, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).watchTeam(teamId);
});

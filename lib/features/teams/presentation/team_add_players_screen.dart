import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import 'widgets/team_add_method_tile.dart';
import 'widgets/team_invite_share_card.dart';

/// Ways to invite players and add them to a team roster.
class TeamAddPlayersScreen extends ConsumerWidget {
  const TeamAddPlayersScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(_teamProvider(teamId));

    return Scaffold(
      appBar: AppBar(
        title: teamAsync.when(
          data: (t) =>
              Text(t == null ? 'Add players' : 'Add players · ${t.name}'),
          loading: () => const Text('Add players'),
          error: (_, __) => const Text('Add players'),
        ),
      ),
      body: teamAsync.when(
        data: (team) {
          if (team == null) {
            return const Center(child: Text('Team not found'));
          }
          return _AddPlayersBody(team: team, teamId: teamId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _AddPlayersBody extends StatelessWidget {
  const _AddPlayersBody({required this.team, required this.teamId});

  final TeamModel team;
  final String teamId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return ListView(
      padding: AppDimens.listPadding.copyWith(bottom: AppDimens.spaceXl),
      children: [
        Text(
          'Grow your squad',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Share an invite link or QR code, look up a player by ID, or add walk-ins without a CrickFlow account.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cf.textSecondary),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        TeamInviteShareCard(team: team),
        const SizedBox(height: AppDimens.spaceLg),
        Text(
          'Add players manually',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        TeamAddMethodTile(
          icon: Icons.badge_outlined,
          title: 'Add registered player',
          subtitle:
              'Search by name or Player ID and send an invitation to join.',
          onTap: () => context.push('/teams/$teamId/add-players/quick'),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        TeamAddMethodTile(
          icon: Icons.person_add_alt_1_outlined,
          title: 'Walk-in player',
          subtitle:
              'Add a guest without a CrickFlow account — name, role, and styles.',
          iconColor: Colors.orange.shade800,
          iconBackground: Colors.orange.withValues(alpha: 0.15),
          onTap: () => context.push('/teams/$teamId/add-players/walkin'),
        ),
      ],
    );
  }
}

final _teamProvider = StreamProvider.family<TeamModel?, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).watchTeam(teamId);
});

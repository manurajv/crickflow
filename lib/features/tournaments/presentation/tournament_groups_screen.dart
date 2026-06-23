import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/tournament/tournament_group_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/widgets/cf_button.dart';
import 'widgets/groups/create_group_dialog.dart';
import 'widgets/groups/select_group_team_sheet.dart';
import 'widgets/teams/tournament_team_confirm_sheet.dart';
import 'widgets/tournament_module_empty_state.dart';

class TournamentGroupsScreen extends ConsumerWidget {
  const TournamentGroupsScreen({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  Future<void> _createGroups(
    BuildContext context,
    WidgetRef ref,
    GroupCreationMethod method,
  ) async {
    final result = await showCreateGroupDialog(context, method: method);
    if (result == null) return;

    try {
      final repo = ref.read(tournamentRepositoryProvider);
      if (result.method == GroupCreationMethod.autoDistribution) {
        await repo.createGroupsAutoDistribution(
          tournamentId: tournament.id,
          groupCount: result.groupCount,
        );
      } else {
        for (final name in result.names) {
          await repo.createGroup(
            tournamentId: tournament.id,
            name: name,
          );
        }
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Groups created')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _showCreationMethodSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final method = await showModalBottomSheet<GroupCreationMethod>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Manual'),
              subtitle: const Text('Name groups and assign teams yourself'),
              onTap: () =>
                  Navigator.pop(ctx, GroupCreationMethod.manual),
            ),
            ListTile(
              leading: const Icon(Icons.shuffle_outlined),
              title: const Text('Auto distribution'),
              subtitle: const Text('Split tournament teams evenly'),
              onTap: () =>
                  Navigator.pop(ctx, GroupCreationMethod.autoDistribution),
            ),
          ],
        ),
      ),
    );
    if (method == null || !context.mounted) return;
    await _createGroups(context, ref, method);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref
        .watch(tournamentPermissionServiceProvider)
        .canManageGroups(role);
    final groupsAsync = ref.watch(tournamentGroupsProvider(tournament.id));
    final liveTournament =
        ref.watch(tournamentProvider(tournament.id)).valueOrNull ?? tournament;

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (groups) {
        if (groups.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tournamentGroupsProvider(tournament.id));
            },
            child: TournamentModuleEmptyState(
              icon: Icons.grid_view_outlined,
              title: 'No Groups Created',
              description:
                  'Create groups to organize teams and generate points tables.',
              primaryAction: canManage
                  ? (
                      label: 'Create Groups',
                      onPressed: () => _showCreationMethodSheet(context, ref),
                    )
                  : null,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tournamentGroupsProvider(tournament.id));
          },
          child: ListView(
            padding: AppDimens.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (canManage) ...[
                CfButton(
                  label: 'Create groups',
                  isGold: true,
                  compact: true,
                  onPressed: () => _showCreationMethodSheet(context, ref),
                ),
                const SizedBox(height: AppDimens.spaceMd),
              ],
              ...groups.map(
                (g) => _GroupCard(
                  group: g,
                  tournament: liveTournament,
                  canManage: canManage,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({
    required this.group,
    required this.tournament,
    required this.canManage,
  });

  final TournamentGroupModel group;
  final TournamentModel tournament;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final allGroups =
        ref.watch(tournamentGroupsProvider(tournament.id)).valueOrNull ?? [];
    final assignedAnywhere = allGroups.expand((g) => g.teamIds).toSet();
    final unassigned = tournament.teamIds
        .where((id) => !assignedAnywhere.contains(id))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (group.qualificationCount > 0)
                  Chip(
                    label: Text('Top ${group.qualificationCount} qualify'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (canManage)
                  PopupMenuButton<String>(
                    onSelected: (v) => switch (v) {
                      'delete' => _deleteGroup(context, ref),
                      _ => null,
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete group'),
                      ),
                    ],
                  ),
              ],
            ),
            if (group.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                group.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              '${group.teamIds.length} teams'
              '${group.qualificationTargetRound.isNotEmpty ? ' · Target: ${group.qualificationTargetRound}' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(
                      '/tournaments/${tournament.id}/points-table',
                    ),
                    child: const Text('Points table'),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showTeamsSheet(context, ref),
                    child: const Text('View teams'),
                  ),
                ),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: unassigned.isEmpty
                      ? null
                      : () => _pickAndAddTeam(context, ref, unassigned),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: Text(
                    unassigned.isEmpty
                        ? 'All teams assigned'
                        : 'Add team',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showTeamsSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: AppDimens.screenPadding,
          children: [
            Text(
              '${group.name} teams',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            if (group.teamIds.isEmpty)
              const Text('No teams assigned yet')
            else
              ...group.teamIds.map(
                (id) => ListTile(
                  title: Text(_teamName(id)),
                  trailing: canManage
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _removeTeam(context, ref, id),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _teamName(String id) {
    return tournament.pointsTable
            .where((e) => e.teamId == id)
            .firstOrNull
            ?.teamName ??
        id;
  }

  Future<void> _pickAndAddTeam(
    BuildContext context,
    WidgetRef ref,
    List<String> unassigned,
  ) async {
    final teamId = await showSelectGroupTeamSheet(
      context: context,
      tournament: tournament,
      teamIds: unassigned,
      title: 'Add team to ${group.name}',
    );
    if (teamId == null || !context.mounted) return;
    await _addTeam(context, ref, teamId);
  }

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showTournamentTeamConfirmSheet(
      context: context,
      title: 'Delete group?',
      message:
          'Remove "${group.name}" and its points table? Teams will become unassigned.',
      confirmLabel: 'Delete group',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(tournamentRepositoryProvider).deleteGroup(group.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${group.name} deleted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _addTeam(
    BuildContext context,
    WidgetRef ref,
    String teamId,
  ) async {
    final next = group.copyWith(teamIds: [...group.teamIds, teamId]);
    try {
      await ref.read(tournamentRepositoryProvider).updateGroup(next);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team added to group')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _removeTeam(
    BuildContext context,
    WidgetRef ref,
    String teamId,
  ) async {
    final next = group.copyWith(
      teamIds: group.teamIds.where((id) => id != teamId).toList(),
    );
    await ref.read(tournamentRepositoryProvider).updateGroup(next);
    if (context.mounted) Navigator.pop(context);
  }
}

typedef TournamentGroupsTab = TournamentGroupsScreen;

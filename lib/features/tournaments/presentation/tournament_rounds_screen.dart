import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/tournament/tournament_round_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import 'widgets/rounds/create_round_dialog.dart';
import 'widgets/tournament_module_empty_state.dart';

class TournamentRoundsScreen extends ConsumerWidget {
  const TournamentRoundsScreen({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  Future<void> _createRound(BuildContext context, WidgetRef ref) async {
    final result = await showCreateRoundDialog(context);
    if (result == null) return;
    try {
      await ref.read(tournamentRepositoryProvider).createRound(
            tournamentId: tournament.id,
            name: result.name,
            roundType: result.roundType,
            description: result.description,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Round "${result.name}" created')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref
        .watch(tournamentPermissionServiceProvider)
        .canManageFixtures(role);
    final roundsAsync = ref.watch(tournamentRoundsProvider(tournament.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament rounds'),
      ),
      body: roundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rounds) {
          if (rounds.isEmpty) {
            return TournamentModuleEmptyState(
              icon: Icons.layers_outlined,
              title: 'No rounds created yet',
              description:
                  'Add league, knockout or custom rounds before scheduling fixtures.',
              primaryAction: canManage
                  ? (
                      label: 'Create Round',
                      onPressed: () => _createRound(context, ref),
                    )
                  : null,
            );
          }

          return ReorderableListView.builder(
            padding: AppDimens.screenPadding,
            itemCount: rounds.length,
            onReorder: canManage
                ? (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final list = List<TournamentRoundModel>.from(rounds);
                    final item = list.removeAt(oldIndex);
                    list.insert(newIndex, item);
                    await ref
                        .read(tournamentRepositoryProvider)
                        .reorderRounds(list);
                  }
                : (_, __) {},
            itemBuilder: (_, i) {
              final round = rounds[i];
              return _RoundTile(
                key: ValueKey(round.id),
                index: i,
                round: round,
                canManage: canManage,
                onToggleActive: () => _toggleActive(ref, round),
                onArchive: () => _archive(ref, round),
                onDelete: () => _delete(context, ref, round),
              );
            },
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _createRound(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create round'),
            )
          : null,
    );
  }

  Future<void> _toggleActive(WidgetRef ref, TournamentRoundModel round) async {
    await ref.read(tournamentRepositoryProvider).updateRound(
          round.copyWith(isActive: !round.isActive),
        );
  }

  Future<void> _archive(WidgetRef ref, TournamentRoundModel round) async {
    await ref.read(tournamentRepositoryProvider).updateRound(
          round.copyWith(isArchived: true, isActive: false),
        );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TournamentRoundModel round,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete round?'),
        content: Text('Remove "${round.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tournamentRepositoryProvider).deleteRound(round.id);
  }
}

class _RoundTile extends StatelessWidget {
  const _RoundTile({
    super.key,
    required this.index,
    required this.round,
    required this.canManage,
    required this.onToggleActive,
    required this.onArchive,
    required this.onDelete,
  });

  final int index;
  final TournamentRoundModel round;
  final bool canManage;
  final VoidCallback onToggleActive;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          enabled: canManage,
          child: Icon(Icons.drag_handle, color: cf.textMuted),
        ),
        title: Text(round.name),
        subtitle: Text(
          '${round.roundType.defaultLabel()}'
          '${round.description.isNotEmpty ? ' · ${round.description}' : ''}',
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (v) => switch (v) {
                  'toggle' => onToggleActive(),
                  'archive' => onArchive(),
                  'delete' => onDelete(),
                  _ => null,
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(round.isActive ? 'Deactivate' : 'Activate'),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              )
            : Chip(
                label: Text(round.isActive ? 'Active' : 'Inactive'),
                visualDensity: VisualDensity.compact,
              ),
      ),
    );
  }
}

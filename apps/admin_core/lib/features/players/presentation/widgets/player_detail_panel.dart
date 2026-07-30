import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_permission.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../../shared/widgets/cf_network_image.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/managed_player.dart';
import '../../models/player_enums.dart';
import '../../providers/players_providers.dart';
import 'player_status_badge.dart';

class PlayerDetailPanel extends ConsumerWidget {
  const PlayerDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedManagedPlayerProvider);
    final colors = context.adminColors;
    final canManage = ref
        .watch(permissionCheckerProvider)
        .can(AdminPermission.canManagePlayers);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 440,
        child: async.when(
          loading: () => const CfLoadingState(message: 'Loading player…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (player) {
            if (player == null) {
              return const Center(child: Text('Select a player'));
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Player details',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Row(
                        children: [
                          CfAvatar(
                            url: player.photoUrl,
                            radius: 28,
                            label: player.displayName,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(player.cfIdLabel),
                                const SizedBox(height: 4),
                                PlayerStatusBadge(status: player.displayStatus),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _kv('Full name',
                          player.fullName.isEmpty ? '—' : player.fullName),
                      _kv('Type',
                          player.isRegistered ? 'Registered' : 'Walk-in'),
                      _kv('User ID', player.userId ?? '—'),
                      _kv('Role', player.role.isEmpty ? '—' : player.role),
                      _kv(
                        'Batting',
                        player.battingStyle.isEmpty ? '—' : player.battingStyle,
                      ),
                      _kv(
                        'Bowling',
                        player.bowlingStyle.isEmpty ? '—' : player.bowlingStyle,
                      ),
                      _kv('Teams', '${player.effectiveTeamIds.length}'),
                      _kv('Location', player.locationLabel),
                      _kv('Matches', '${player.matchesPlayed}'),
                      _kv('Runs', '${player.runs}'),
                      _kv('Wickets', '${player.wickets}'),
                      _kv(
                        'Created',
                        player.createdAt == null
                            ? '—'
                            : DateFormat('yyyy-MM-dd HH:mm')
                                .format(player.createdAt!),
                      ),
                      const SizedBox(height: 16),
                      if (canManage) ...[
                        Text(
                          'Actions',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            CfButton(
                              label: player.adminFeatured
                                  ? 'Unfeature'
                                  : 'Feature',
                              variant: CfButtonVariant.secondary,
                              onPressed: () => ref
                                  .read(playersListControllerProvider.notifier)
                                  .setFeatured(player, !player.adminFeatured),
                            ),
                            CfButton(
                              label: player.adminVerified
                                  ? 'Unverify'
                                  : 'Verify',
                              variant: CfButtonVariant.secondary,
                              onPressed: () => ref
                                  .read(playersListControllerProvider.notifier)
                                  .setVerified(player, !player.adminVerified),
                            ),
                            CfButton(
                              label: 'Suspend',
                              variant: CfButtonVariant.danger,
                              onPressed: () => ref
                                  .read(playersListControllerProvider.notifier)
                                  .setStatus(
                                    player,
                                    ManagedPlayerStatus.suspended,
                                  ),
                            ),
                            if (player.isSoftDeleted)
                              CfButton(
                                label: 'Restore',
                                onPressed: () => ref
                                    .read(
                                        playersListControllerProvider.notifier)
                                    .restore(player),
                              )
                            else
                              CfButton(
                                label: 'Soft delete',
                                variant: CfButtonVariant.danger,
                                onPressed: () => _confirmSoftDelete(
                                  context,
                                  ref,
                                  player,
                                ),
                              ),
                            CfButton(
                              label: 'Edit profile',
                              variant: CfButtonVariant.secondary,
                              onPressed: () =>
                                  _editProfile(context, ref, player),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Recent audit',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ref.watch(playerAuditProvider(player.id)).when(
                            loading: () => const Text('Loading audit…'),
                            error: (e, _) => Text('$e'),
                            data: (logs) {
                              if (logs.isEmpty) {
                                return const Text('No audit entries yet.');
                              }
                              return Column(
                                children: [
                                  for (final e in logs.take(12))
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text(e.action),
                                      subtitle: Text(
                                        e.actorEmail.isEmpty
                                            ? e.actorUid
                                            : e.actorEmail,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Future<void> _confirmSoftDelete(
    BuildContext context,
    WidgetRef ref,
    ManagedPlayer player,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Soft delete player?'),
        content: Text(
          'Marks ${player.displayName} as deleted in admin metadata. '
          'Does not remove the mobile profile document.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Soft delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(playersListControllerProvider.notifier).softDelete(player);
    }
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    ManagedPlayer player,
  ) async {
    final name = TextEditingController(text: player.name);
    final fullName = TextEditingController(text: player.fullName);
    final role = TextEditingController(text: player.role);
    final batting = TextEditingController(text: player.battingStyle);
    final bowling = TextEditingController(text: player.bowlingStyle);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit player profile'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Display name'),
                ),
                TextField(
                  controller: fullName,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                TextField(
                  controller: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                TextField(
                  controller: batting,
                  decoration: const InputDecoration(labelText: 'Batting style'),
                ),
                TextField(
                  controller: bowling,
                  decoration: const InputDecoration(labelText: 'Bowling style'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(playersListControllerProvider.notifier).updateBasicInfo(
            player: player,
            name: name.text,
            fullName: fullName.text,
            role: role.text,
            battingStyle: batting.text,
            bowlingStyle: bowling.text,
          );
    }
    name.dispose();
    fullName.dispose();
    role.dispose();
    batting.dispose();
    bowling.dispose();
  }
}

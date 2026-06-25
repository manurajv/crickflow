import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament/tournament_official_model.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../utils/tournament_display_utils.dart';
import '../widgets/officials/add_tournament_official_sheet.dart';
import '../widgets/overview/tournament_overview_widgets.dart';
import '../widgets/tournament_module_empty_state.dart';
import '../widgets/teams/tournament_team_confirm_sheet.dart';

class TournamentOfficialsTab extends ConsumerWidget {
  const TournamentOfficialsTab({
    super.key,
    required this.tournamentId,
    required this.role,
  });

  final String tournamentId;
  final TournamentRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final tournament =
        ref.watch(tournamentProvider(tournamentId)).valueOrNull;
    final officialsAsync = ref.watch(tournamentOfficialsProvider(tournamentId));
    final canManage =
        ref.watch(tournamentPermissionServiceProvider).canManageOfficials(role);

    if (tournament == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return officialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) {
        final visible = list
            .where((o) => o.status != TournamentOfficialStatus.declined)
            .toList();
        final activeCount =
            visible.where((o) => o.status == TournamentOfficialStatus.active).length;
        final pendingCount =
            visible.where((o) => o.status == TournamentOfficialStatus.pending).length;

        if (visible.isEmpty && !canManage) {
          return const TournamentModuleEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'No officials assigned',
            description:
                'Tournament officials will appear here once the organizer adds them.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tournamentOfficialsProvider(tournamentId));
          },
          child: ListView(
            padding: AppDimens.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (canManage)
                Container(
                  padding: AppDimens.cardPadding,
                  margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                  decoration: BoxDecoration(
                    color: cf.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cf.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: cf.accent, size: 20),
                      const SizedBox(width: AppDimens.spaceSm),
                      Expanded(
                        child: Text(
                          'Active officials auto-fill match setup. '
                          'You can change them per match when starting. '
                          'Invitations are sent to everyone except yourself.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cf.textPrimary,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              TournamentOverviewSectionCard(
                title: 'Officials roster',
                trailing: Text(
                  '$activeCount active · $pendingCount pending',
                  style: TextStyle(color: cf.textSecondary, fontSize: 12),
                ),
                action: canManage
                    ? CfButton(
                        label: 'Add official',
                        isGold: true,
                        onPressed: () => showAddTournamentOfficialSheet(
                          context: context,
                          ref: ref,
                          tournament: tournament,
                        ),
                      )
                    : null,
                child: visible.isEmpty
                    ? const TournamentOverviewEmptyInline(
                        message:
                            'Add umpires, scorers, commentators, and other officials.',
                      )
                    : Column(
                        children: [
                          for (final roleType in TournamentOfficialRole.values)
                            _RoleSection(
                              role: roleType,
                              officials: visible
                                  .where((o) => o.role == roleType)
                                  .toList(),
                              canManage: canManage,
                              onAdd: canManage
                                  ? () => showAddTournamentOfficialSheet(
                                        context: context,
                                        ref: ref,
                                        tournament: tournament,
                                        initialRole: roleType,
                                      )
                                  : null,
                              onRemove: canManage
                                  ? (official) =>
                                      _confirmRemove(context, ref, official)
                                  : null,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    TournamentOfficialModel official,
  ) async {
    final confirmed = await showTournamentTeamConfirmSheet(
      context: context,
      title: 'Remove official?',
      message:
          'Remove ${official.displayName} as ${tournamentOfficialRoleSingular(official.role)}?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(tournamentOfficialRepositoryProvider).removeOfficial(official.id);
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.role,
    required this.officials,
    required this.canManage,
    this.onAdd,
    this.onRemove,
  });

  final TournamentOfficialRole role;
  final List<TournamentOfficialModel> officials;
  final bool canManage;
  final VoidCallback? onAdd;
  final void Function(TournamentOfficialModel official)? onRemove;

  @override
  Widget build(BuildContext context) {
    if (officials.isEmpty && !canManage) return const SizedBox.shrink();

    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_roleIcon(role), size: 18, color: cf.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tournamentOfficialRoleLabel(role),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (canManage && onAdd != null)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
            ],
          ),
          if (officials.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No ${tournamentOfficialRoleLabel(role).toLowerCase()} yet',
                style: TextStyle(color: cf.textMuted, fontSize: 13),
              ),
            )
          else
            ...officials.map(
              (o) => _OfficialCard(
                official: o,
                onRemove: onRemove == null ? null : () => onRemove!(o),
              ),
            ),
        ],
      ),
    );
  }

  IconData _roleIcon(TournamentOfficialRole role) => switch (role) {
        TournamentOfficialRole.scorer => Icons.scoreboard_outlined,
        TournamentOfficialRole.umpire => Icons.sports_outlined,
        TournamentOfficialRole.commentator => Icons.mic_outlined,
        TournamentOfficialRole.streamer => Icons.videocam_outlined,
        TournamentOfficialRole.photographer => Icons.camera_alt_outlined,
        TournamentOfficialRole.videographer => Icons.movie_outlined,
      };
}

class _OfficialCard extends StatelessWidget {
  const _OfficialCard({
    required this.official,
    this.onRemove,
  });

  final TournamentOfficialModel official;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final name = official.displayName.isNotEmpty
        ? official.displayName
        : 'Official';
    final (statusLabel, statusColor) = switch (official.status) {
      TournamentOfficialStatus.pending => ('Pending invite', cf.accent),
      TournamentOfficialStatus.declined => ('Declined', cf.textMuted),
      TournamentOfficialStatus.active => ('Active', cf.success),
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: cf.sectionBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cf.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cf.card,
          backgroundImage: official.photoUrl != null
              ? CachedNetworkImageProvider(official.photoUrl!)
              : null,
          child: official.photoUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (official.playerId.isNotEmpty) official.playerId,
            tournamentOfficialRoleSingular(official.role),
          ].join(' · '),
          style: TextStyle(color: cf.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: cf.textMuted),
                onPressed: onRemove,
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}

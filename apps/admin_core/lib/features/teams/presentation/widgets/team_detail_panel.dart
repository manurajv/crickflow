import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_permission.dart';
import '../../../../models/admin_role.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/managed_team.dart';
import '../../models/team_enums.dart';
import '../../providers/teams_providers.dart';
import 'team_status_badge.dart';

class TeamDetailPanel extends ConsumerWidget {
  const TeamDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedManagedTeamProvider);
    final colors = context.adminColors;
    final canManage = ref
        .watch(permissionCheckerProvider)
        .can(AdminPermission.canManageTeams);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 440,
        child: async.when(
          loading: () => const CfLoadingState(message: 'Loading team…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (team) {
            if (team == null) {
              return const Center(child: Text('Select a team'));
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
                          'Team details',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
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
                      _Hero(team: team),
                      const SizedBox(height: 12),
                      _Overview(team: team),
                      const SizedBox(height: 16),
                      _Stats(team: team),
                      const SizedBox(height: 16),
                      if (canManage) ...[
                        _Actions(team: team),
                        const SizedBox(height: 16),
                      ],
                      _AuditSection(),
                      const SizedBox(height: 16),
                      const _SectionTitle('Related (placeholders)'),
                      const SizedBox(height: 8),
                      const _PlaceholderList(
                        items: [
                          'Members roster',
                          'Matches (upcoming / live / completed)',
                          'Tournaments & trophies',
                          'Followers',
                          'Reports',
                          'Advanced statistics',
                        ],
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
}

class _Hero extends StatelessWidget {
  const _Hero({required this.team});

  final ManagedTeam team;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final banner = team.coverUrl;
    return Column(
      children: [
        Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colors.background,
            border: Border.all(color: colors.border),
            image: banner != null && banner.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(banner),
                    fit: BoxFit.cover,
                    onError: (_, _) {},
                  )
                : null,
          ),
          child: banner == null || banner.isEmpty
              ? Icon(Icons.image_outlined, color: colors.textMuted)
              : null,
        ),
        const SizedBox(height: 12),
        CircleAvatar(
          radius: 32,
          backgroundColor: colors.background,
          child: team.logoUrl == null || team.logoUrl!.isEmpty
              ? Icon(Icons.groups, color: colors.textMuted)
              : ClipOval(
                  child: Image.network(
                    team.logoUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.groups, color: colors.textMuted),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          team.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          team.shortLabel,
          style: TextStyle(color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            TeamStatusBadge(status: team.displayStatus),
            TeamVerifiedBadge(verified: team.isVerified),
            TeamFeaturedBadge(featured: team.adminFeatured),
            if (team.category != null)
              Chip(
                label: Text(team.category!.label),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.team});

  final ManagedTeam team;

  @override
  Widget build(BuildContext context) {
    final t = team;
    final rows = <MapEntry<String, String>>[
      MapEntry('Captain', t.captainId ?? '—'),
      MapEntry('Vice Captain', t.viceCaptainId ?? '—'),
      MapEntry('Coach', t.coachName.isEmpty ? '—' : t.coachName),
      MapEntry('Manager / Owner', t.createdBy ?? '—'),
      MapEntry('Contact', t.contactNumber.isEmpty ? '—' : t.contactNumber),
      MapEntry('Location', t.locationLabel),
      MapEntry('Home ground', t.placeName.isEmpty ? '—' : t.placeName),
      MapEntry('Members', '${t.memberCount}'),
      MapEntry('Followers', '${t.followersCount}'),
      MapEntry('Ball type', t.ballType?.label ?? '—'),
      MapEntry('Category', t.category?.label ?? '—'),
      MapEntry(
        'Founded',
        t.createdAt == null ? '—' : '${t.createdAt!.year}',
      ),
      if (t.isSoftDeleted)
        MapEntry(
          'Deleted at',
          t.deletedAt == null
              ? '—'
              : DateFormat('yyyy-MM-dd HH:mm').format(t.deletedAt!),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Overview'),
        const SizedBox(height: 8),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    row.key,
                    style: TextStyle(
                      color: context.adminColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Text(row.value)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () async {
            final path = '/teams/${t.id}/profile';
            final uri = Uri.parse(
              'https://crickflow.app/open-app.html?path=${Uri.encodeComponent(path)}',
            );
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open Mobile Team Profile'),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.team});

  final ManagedTeam team;

  @override
  Widget build(BuildContext context) {
    final t = team;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Statistics'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(context, 'Matches', '${t.matchesPlayed}'),
            _chip(context, 'Wins', '${t.matchesWon}'),
            _chip(context, 'Losses', '${t.matchesLost}'),
            _chip(context, 'Tied', '${t.matchesTied}'),
            _chip(context, 'Win %', t.winPctLabel),
            _chip(context, 'Runs', '${t.totalRunsScored}'),
            _chip(context, 'Wickets', '${t.totalWicketsTaken}'),
            _chip(context, 'Views', '${t.profileViewsCount}'),
          ],
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    final colors = context.adminColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            label,
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AuditSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedTeamAuditProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Audit Log'),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (items) => items.isEmpty
              ? Text(
                  'No admin actions yet',
                  style: TextStyle(color: context.adminColors.textMuted),
                )
              : Column(
                  children: [
                    for (final item in items.take(20))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.action),
                        subtitle: Text(item.reason ?? item.actorEmail),
                        trailing: Text(
                          DateFormat('MMM d HH:mm').format(item.timestamp),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.team});

  final ManagedTeam team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(teamsListControllerProvider.notifier);
    final isSuper =
        AdminRole.tryParse(ref.watch(adminSessionProvider).adminUser?.roleId) ==
            AdminRole.superAdmin;

    Future<void> confirmAction({
      required String title,
      required String message,
      required Future<void> Function(String? reason) run,
      bool danger = false,
    }) async {
      final reasonController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            CfButton(
              label: 'Cancel',
              variant: CfButtonVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
            CfButton(
              label: 'Confirm',
              variant:
                  danger ? CfButtonVariant.danger : CfButtonVariant.primary,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (ok == true) {
        await run(
          reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title completed')),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _editBasicInfo(context, ref, team),
              child: const Text('Edit Basic Info'),
            ),
            if (isSuper) ...[
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: team.isVerified
                      ? 'Remove Verification'
                      : 'Verify Team',
                  message: team.isVerified
                      ? 'Remove platform verification?'
                      : 'Mark this team as verified?',
                  run: (r) =>
                      controller.setVerified(team, !team.isVerified, reason: r),
                ),
                child: Text(team.isVerified ? 'Unverify' : 'Verify'),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: team.displayStatus == ManagedTeamStatus.suspended
                      ? 'Unsuspend Team'
                      : 'Suspend Team',
                  message: team.displayStatus == ManagedTeamStatus.suspended
                      ? 'Restore team to active status?'
                      : 'Suspend this team?',
                  danger: team.displayStatus != ManagedTeamStatus.suspended,
                  run: (r) => controller.setStatus(
                    team,
                    team.displayStatus == ManagedTeamStatus.suspended
                        ? ManagedTeamStatus.active
                        : ManagedTeamStatus.suspended,
                    reason: r,
                  ),
                ),
                child: Text(
                  team.displayStatus == ManagedTeamStatus.suspended
                      ? 'Unsuspend'
                      : 'Suspend',
                ),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: team.adminFeatured
                      ? 'Remove Feature'
                      : 'Feature Team',
                  message: team.adminFeatured
                      ? 'Remove team feature?'
                      : 'Feature this team?',
                  run: (r) => controller.setFeatured(
                    team,
                    !team.adminFeatured,
                    reason: r,
                  ),
                ),
                child: Text(team.adminFeatured ? 'Unfeature' : 'Feature'),
              ),
              if (!team.isSoftDeleted)
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Soft-delete Team',
                    message:
                        'Soft-delete this team? Roster and match history stay intact.',
                    danger: true,
                    run: (r) => controller.softDelete(team, reason: r),
                  ),
                  child: const Text('Delete'),
                )
              else
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Restore Team',
                    message: 'Restore this team?',
                    run: (r) => controller.restore(team, reason: r),
                  ),
                  child: const Text('Restore'),
                ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Archive Team',
                  message: 'Archive this team?',
                  run: (r) => controller.archive(team, reason: r),
                ),
                child: const Text('Archive'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _editBasicInfo(
    BuildContext context,
    WidgetRef ref,
    ManagedTeam team,
  ) async {
    final name = TextEditingController(text: team.name);
    final coach = TextEditingController(text: team.coachName);
    final contact = TextEditingController(text: team.contactNumber);
    ManagedTeamCategory? category = team.category;
    ManagedTeamBallType? ballType = team.ballType;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Edit Team Information'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: coach,
                      decoration: const InputDecoration(labelText: 'Coach'),
                    ),
                    TextField(
                      controller: contact,
                      decoration: const InputDecoration(labelText: 'Contact'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ManagedTeamCategory?>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        for (final c in ManagedTeamCategory.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: (v) => setLocal(() => category = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ManagedTeamBallType?>(
                      initialValue: ballType,
                      decoration: const InputDecoration(labelText: 'Ball type'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        for (final b in ManagedTeamBallType.values)
                          DropdownMenuItem(value: b, child: Text(b.label)),
                      ],
                      onChanged: (v) => setLocal(() => ballType = v),
                    ),
                  ],
                ),
              ),
              actions: [
                CfButton(
                  label: 'Cancel',
                  variant: CfButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context, false),
                ),
                CfButton(
                  label: 'Save',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      await ref.read(teamsListControllerProvider.notifier).saveBasicInfo(
            team,
            name: name.text.trim(),
            coachName: coach.text.trim(),
            contactNumber: contact.text.trim(),
            category: category,
            ballType: ballType,
          );
    }
  }
}

class _PlaceholderList extends StatelessWidget {
  const _PlaceholderList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      children: [
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(item),
            subtitle: Text(
              'Coming soon',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            trailing: Icon(
              Icons.lock_outline,
              size: 16,
              color: colors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

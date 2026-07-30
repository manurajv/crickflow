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
import '../../models/managed_tournament.dart';
import '../../models/tournament_enums.dart';
import '../../providers/tournaments_providers.dart';
import 'tournament_status_badge.dart';

class TournamentDetailPanel extends ConsumerWidget {
  const TournamentDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedManagedTournamentProvider);
    final colors = context.adminColors;
    final canManage = ref
        .watch(permissionCheckerProvider)
        .can(AdminPermission.canManageTournaments);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 440,
        child: async.when(
          loading: () =>
              const CfLoadingState(message: 'Loading tournament…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (tournament) {
            if (tournament == null) {
              return const Center(child: Text('Select a tournament'));
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
                          'Tournament details',
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
                      _Hero(tournament: tournament),
                      const SizedBox(height: 12),
                      _Info(tournament: tournament),
                      const SizedBox(height: 16),
                      _PointsPreview(rows: tournament.pointsTable),
                      const SizedBox(height: 16),
                      if (canManage) ...[
                        _Actions(tournament: tournament),
                        const SizedBox(height: 16),
                      ],
                      const _SectionTitle('Related (placeholders)'),
                      const SizedBox(height: 8),
                      const _PlaceholderList(
                        items: [
                          'Participating teams',
                          'Fixtures & results',
                          'Officials / scorers / umpires',
                          'Streaming crew',
                          'Live monitor',
                          'Reports',
                          'Tournament statistics',
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
  const _Hero({required this.tournament});

  final ManagedTournament tournament;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final banner = tournament.bannerUrl ?? tournament.posterUrl;
    return Column(
      children: [
        Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colors.background,
            border: Border.all(color: colors.border),
            image: banner.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(banner),
                    fit: BoxFit.cover,
                    onError: (_, _) {},
                  )
                : null,
          ),
          child: banner.isEmpty
              ? Icon(Icons.image_outlined, color: colors.textMuted)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          tournament.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        Text(
          tournament.tournamentCode ?? tournament.id,
          style: TextStyle(color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            TournamentStatusBadge(status: tournament.status),
            TournamentApprovalBadge(approval: tournament.adminApproval),
            TournamentFeaturedBadge(featured: tournament.adminFeatured),
            Chip(
              label: Text(tournament.format.label),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.tournament});

  final ManagedTournament tournament;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    final rows = <MapEntry<String, String>>[
      MapEntry('Organizer', t.organizerName.isEmpty ? '—' : t.organizerName),
      MapEntry('Contact', [
        if (t.organizerPhone.isNotEmpty) t.organizerPhone,
        if (t.organizerEmail.isNotEmpty) t.organizerEmail,
      ].join(' · ').ifEmpty('—')),
      MapEntry('Location', t.locationLabel),
      MapEntry(
        'Grounds',
        t.grounds.isEmpty ? '—' : t.grounds.join(', '),
      ),
      MapEntry(
        'Entry fee',
        t.isFree ? 'Free' : (t.entryFee?.toStringAsFixed(0) ?? '—'),
      ),
      MapEntry('Prize', t.winningPrize?.isNotEmpty == true ? t.winningPrize! : '—'),
      MapEntry('Ball', t.ballType?.label ?? '—'),
      MapEntry('Teams', '${t.teamCount}${t.teamsRequired != null ? ' / ${t.teamsRequired}' : ''}'),
      MapEntry('Matches', '${t.matchCount}'),
      MapEntry(
        'Dates',
        [
          if (t.startDate != null) DateFormat('yyyy-MM-dd').format(t.startDate!),
          if (t.endDate != null) DateFormat('yyyy-MM-dd').format(t.endDate!),
        ].join(' → ').ifEmpty('—'),
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
        if (t.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(t.description),
          ),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
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
          onPressed: t.effectiveOrganizerId.isEmpty
              ? null
              : () async {
                  final path = '/player/${t.effectiveOrganizerId}';
                  final uri = Uri.parse(
                    'https://crickflow.app/open-app.html?path=${Uri.encodeComponent(path)}',
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
          icon: const Icon(Icons.person_outline, size: 18),
          label: const Text('Open Organizer Profile'),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _PointsPreview extends StatelessWidget {
  const _PointsPreview({required this.rows});

  final List<PointsTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Points table'),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text('No standings yet', style: TextStyle(color: colors.textMuted))
        else
          ...rows.take(8).map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    r.teamName.isEmpty ? r.teamId : r.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'P ${r.played}  W ${r.won}  L ${r.lost}  T ${r.tied}  NR ${r.noResult}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    '${r.points} pts · NRR ${r.netRunRate.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.tournament});

  final ManagedTournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(tournamentsListControllerProvider.notifier);
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
        try {
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
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e')),
            );
          }
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
            if (isSuper) ...[
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Approve tournament',
                  message: 'Mark this tournament as approved?',
                  run: (r) => controller.setApproval(
                    tournament,
                    AdminTournamentApproval.approved,
                    reason: r,
                  ),
                ),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Reject tournament',
                  message: 'Reject this tournament?',
                  danger: true,
                  run: (r) => controller.setApproval(
                    tournament,
                    AdminTournamentApproval.rejected,
                    reason: r,
                  ),
                ),
                child: const Text('Reject'),
              ),
            ],
            OutlinedButton(
              onPressed: () => confirmAction(
                title: tournament.adminFeatured
                    ? 'Remove feature'
                    : 'Feature tournament',
                message: tournament.adminFeatured
                    ? 'Remove featured highlight?'
                    : 'Feature this tournament on the platform?',
                run: (r) => controller.setFeatured(
                  tournament,
                  !tournament.adminFeatured,
                  reason: r,
                ),
              ),
              child: Text(
                tournament.adminFeatured ? 'Unfeature' : 'Feature',
              ),
            ),
            OutlinedButton(
              onPressed: () => _editBasic(context, ref, tournament),
              child: const Text('Edit'),
            ),
            if (tournament.status != ManagedTournamentStatus.cancelled)
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Cancel tournament',
                  message:
                      'Set mobile status to cancelled? Teams and matches stay.',
                  danger: true,
                  run: (r) => controller.cancel(tournament, reason: r),
                ),
                child: const Text('Cancel'),
              ),
            if (!tournament.isSoftDeleted) ...[
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Soft-delete tournament',
                  message:
                      'Soft-delete ${tournament.name}?\n\n'
                      'History, teams, matches, and scorecards stay in Firestore '
                      'and can be restored. No documents are permanently removed.',
                  danger: true,
                  run: (r) => controller.softDelete(tournament, reason: r),
                ),
                child: const Text('Delete'),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Archive tournament',
                  message: 'Archive ${tournament.name}?',
                  run: (r) => controller.archive(tournament, reason: r),
                ),
                child: const Text('Archive'),
              ),
            ] else
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Restore tournament',
                  message: 'Restore ${tournament.name}?',
                  run: (r) => controller.restore(tournament, reason: r),
                ),
                child: const Text('Restore'),
              ),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Duplicate tournament — coming soon'),
                  ),
                );
              },
              child: const Text('Duplicate'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editBasic(
    BuildContext context,
    WidgetRef ref,
    ManagedTournament t,
  ) async {
    final name = TextEditingController(text: t.name);
    final desc = TextEditingController(text: t.description);
    final prize = TextEditingController(text: t.winningPrize ?? '');
    final fee = TextEditingController(
      text: t.entryFee == null ? '' : t.entryFee!.toStringAsFixed(0),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit tournament'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                TextField(
                  controller: prize,
                  decoration: const InputDecoration(labelText: 'Prize money'),
                ),
                TextField(
                  controller: fee,
                  decoration: const InputDecoration(labelText: 'Entry fee'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
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
      ),
    );
    if (ok == true) {
      await ref.read(tournamentsListControllerProvider.notifier).saveBasicInfo(
            t,
            name: name.text.trim(),
            description: desc.text.trim(),
            winningPrize: prize.text.trim(),
            entryFee: double.tryParse(fee.text.trim()),
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
            trailing:
                Icon(Icons.lock_outline, size: 16, color: colors.textMuted),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_permission.dart';
import '../../../../models/admin_role.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/match_enums.dart';
import '../../models/managed_match.dart';
import '../../providers/matches_providers.dart';
import 'match_status_badge.dart';

class MatchDetailPanel extends ConsumerWidget {
  const MatchDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedManagedMatchProvider);
    final colors = context.adminColors;
    final canManage = ref
        .watch(permissionCheckerProvider)
        .can(AdminPermission.canManageMatches);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 460,
        child: async.when(
          loading: () => const CfLoadingState(message: 'Loading match...'),
          error: (e, _) => Center(child: Text('$e')),
          data: (match) {
            if (match == null) {
              return const Center(child: Text('Select a match'));
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
                          'Match details',
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
                      _Hero(match: match),
                      const SizedBox(height: 16),
                      _Overview(match: match),
                      const SizedBox(height: 16),
                      _LiveScore(match: match),
                      const SizedBox(height: 16),
                      _Streaming(match: match),
                      const SizedBox(height: 16),
                      _CommentarySection(),
                      const SizedBox(height: 16),
                      _TimelineSection(),
                      const SizedBox(height: 16),
                      _AuditSection(),
                      const SizedBox(height: 16),
                      if (canManage) _Actions(match: match),
                      const SizedBox(height: 16),
                      const _PlaceholderList(
                        items: [
                          'Teams & XI',
                          'Officials',
                          'Reports',
                          'Advanced statistics',
                          'Broadcast monitor',
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
  const _Hero({required this.match});

  final ManagedMatch match;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      children: [
        Text(
          match.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(match.id, style: TextStyle(color: colors.textMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            MatchStatusBadge(status: match.status),
            MatchStreamingBadge(
              isStreaming: match.isStreaming,
              platform: match.streamingPlatform,
            ),
            MatchFeaturedBadge(featured: match.adminFeatured),
            if (match.adminPaused)
              const Chip(
                label: Text('Paused'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}
class _Overview extends StatelessWidget {
  const _Overview({required this.match});

  final ManagedMatch match;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Tournament', match.tournamentName ?? '—'),
      MapEntry('Venue', match.venueLabel),
      MapEntry(
        'Date',
        match.scheduledAt == null
            ? '—'
            : DateFormat('yyyy-MM-dd HH:mm').format(match.scheduledAt!),
      ),
      MapEntry('Ball type', match.ballType?.label ?? '—'),
      MapEntry('Format', match.cricketType?.label ?? '—'),
      MapEntry('Status', match.status.label),
      MapEntry(
        'Toss',
        [
          if (match.tossWinner != null) match.tossWinner!,
          if (match.tossDecision != null) match.tossDecision!,
        ].join(' · ').ifEmpty('—'),
      ),
      MapEntry(
        'Scorer',
        match.currentScorerName.isEmpty ? '—' : match.currentScorerName,
      ),
      MapEntry(
        'Result',
        match.resultSummary.isEmpty ? '—' : match.resultSummary,
      ),
      if (match.isSoftDeleted)
        MapEntry(
          'Deleted at',
          match.deletedAt == null
              ? '—'
              : DateFormat('yyyy-MM-dd HH:mm').format(match.deletedAt!),
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
      ],
    );
  }
}
class _LiveScore extends StatelessWidget {
  const _LiveScore({required this.match});

  final ManagedMatch match;

  @override
  Widget build(BuildContext context) {
    final live = match.live;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Live Score'),
        const SizedBox(height: 8),
        Row(
          children: [
            _stat(context, 'Score', match.scoreLine),
            _stat(context, 'Overs', live.oversText),
            _stat(context, 'Innings', '${match.currentInnings}'),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Batters: ${[live.strikerName, live.nonStrikerName].whereType<String>().where((e) => e.isNotEmpty).join(' & ').ifEmpty('—')}',
        ),
        const SizedBox(height: 4),
        Text('Bowler: ${live.currentBowlerName?.ifEmpty('—') ?? '—'}'),
        const SizedBox(height: 4),
        Text('Partnership: ${live.partnershipRuns} (${live.partnershipBalls})'),
        const SizedBox(height: 4),
        Text('CRR: ${live.currentRunRate.toStringAsFixed(2)}'),
        if (live.requiredRuns != null) ...[
          const SizedBox(height: 4),
          Text(
            'Required: ${live.requiredRuns} · RRR ${live.requiredRunRate?.toStringAsFixed(2) ?? '—'}',
          ),
        ],
        const SizedBox(height: 4),
        Text('Extras: ${live.extras} · Fours: ${live.fours} · Sixes: ${live.sixes}'),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.adminColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.adminColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              label,
              style: TextStyle(color: context.adminColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
class _Streaming extends StatelessWidget {
  const _Streaming({required this.match});

  final ManagedMatch match;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Streaming'),
        const SizedBox(height: 8),
        Text('Status: ${match.streamingStatus.label}'),
        const SizedBox(height: 4),
        Text('Platform: ${match.streamingPlatform.label}'),
        const SizedBox(height: 4),
        Text('Watch URL: ${match.watchUrl ?? '—'}'),
        const SizedBox(height: 4),
        Text('Broadcast URL: ${match.broadcastUrl ?? '—'}'),
        const SizedBox(height: 4),
        Text('Current viewers: ${match.viewerCount}'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: match.watchUrl == null
                  ? null
                  : () => launchUrl(
                        Uri.parse(match.watchUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
              child: const Text('Open Watch URL'),
            ),
            OutlinedButton(
              onPressed: match.watchUrl == null
                  ? null
                  : () => Clipboard.setData(
                        ClipboardData(text: match.watchUrl!),
                      ),
              child: const Text('Copy Watch URL'),
            ),
          ],
        ),
      ],
    );
  }
}
class _CommentarySection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CommentarySection> createState() => _CommentarySectionState();
}

class _CommentarySectionState extends ConsumerState<_CommentarySection> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(matchesListControllerProvider).commentaryQuery,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(matchesListControllerProvider.notifier);
    final async = ref.watch(selectedMatchCommentaryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Commentary'),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: controller.setCommentaryQuery,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search commentary…',
          ),
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (items) => items.isEmpty
              ? Text(
                  'No commentary yet',
                  style: TextStyle(color: context.adminColors.textMuted),
                )
              : Column(
                  children: [
                    for (final item in items.take(20))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.text),
                        subtitle: Text(item.overLabel ?? ''),
                        trailing: Text(
                          item.timestamp == null
                              ? ''
                              : DateFormat('MMM d HH:mm')
                                  .format(item.timestamp!),
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
class _TimelineSection extends ConsumerWidget { @override Widget build(BuildContext context, WidgetRef ref) { final async = ref.watch(selectedMatchTimelineProvider); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _SectionTitle('Timeline'), const SizedBox(height: 8), async.when(loading: () => const LinearProgressIndicator(), error: (e, _) => Text('$e'), data: (items) => items.isEmpty ? Text('No timeline yet', style: TextStyle(color: context.adminColors.textMuted)) : Column(children: [for (final item in items.take(20)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(item.title), subtitle: Text(item.subtitle), trailing: Text(DateFormat('MMM d HH:mm').format(item.occurredAt), style: Theme.of(context).textTheme.labelSmall))]))]); }}
class _AuditSection extends ConsumerWidget { @override Widget build(BuildContext context, WidgetRef ref) { final async = ref.watch(selectedMatchAuditProvider); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _SectionTitle('Audit Log'), const SizedBox(height: 8), async.when(loading: () => const LinearProgressIndicator(), error: (e, _) => Text('$e'), data: (items) => items.isEmpty ? Text('No admin actions yet', style: TextStyle(color: context.adminColors.textMuted)) : Column(children: [for (final item in items.take(20)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(item.action), subtitle: Text(item.reason ?? item.actorEmail), trailing: Text(DateFormat('MMM d HH:mm').format(item.timestamp), style: Theme.of(context).textTheme.labelSmall))]))]); }}
class _Actions extends ConsumerWidget {
  const _Actions({required this.match});
  final ManagedMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(matchesListControllerProvider.notifier);
    final isSuper = AdminRole.tryParse(
          ref.watch(adminSessionProvider).adminUser?.roleId,
        ) ==
        AdminRole.superAdmin;

    Future<void> confirmAction({
      required String title,
      required String message,
      required Future<void> Function(String? reason) run,
      bool danger = false,
    }) async {
      final reasonController = TextEditingController();
      try {
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
                  decoration:
                      const InputDecoration(labelText: 'Reason (optional)'),
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
      } finally {
        reasonController.dispose();
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
            OutlinedButton(onPressed: () {}, child: const Text('View Match')),
            OutlinedButton(
              onPressed: () => _editMetadata(context, ref, match),
              child: const Text('Edit Metadata'),
            ),
            if (isSuper) ...[
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: match.adminPaused ? 'Resume Match' : 'Pause Match',
                  message: match.adminPaused
                      ? 'Resume admin monitoring state?'
                      : 'Pause admin monitoring state? This does not alter scoring engine.',
                  run: (r) =>
                      controller.setPaused(match, !match.adminPaused, reason: r),
                ),
                child: Text(match.adminPaused ? 'Resume' : 'Pause'),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Cancel Match',
                  message: 'Mark this match as cancelled?',
                  danger: true,
                  run: (r) => controller.setStatus(
                    match,
                    ManagedMatchStatus.cancelled,
                    reason: r,
                  ),
                ),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Mark Abandoned',
                  message: 'Mark this match as abandoned?',
                  danger: true,
                  run: (r) => controller.setStatus(
                    match,
                    ManagedMatchStatus.abandoned,
                    reason: r,
                  ),
                ),
                child: const Text('Abandon'),
              ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: match.adminFeatured
                      ? 'Remove Feature'
                      : 'Feature Match',
                  message: match.adminFeatured
                      ? 'Remove match feature?'
                      : 'Feature this match?',
                  run: (r) => controller.setFeatured(
                    match,
                    !match.adminFeatured,
                    reason: r,
                  ),
                ),
                child: Text(match.adminFeatured ? 'Unfeature' : 'Feature'),
              ),
              if (!match.isSoftDeleted)
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Soft-delete Match',
                    message:
                        'Soft-delete this match? History and score data stay intact.',
                    danger: true,
                    run: (r) => controller.softDelete(match, reason: r),
                  ),
                  child: const Text('Delete'),
                )
              else
                OutlinedButton(
                  onPressed: () => confirmAction(
                    title: 'Restore Match',
                    message: 'Restore this match?',
                    run: (r) => controller.restore(match, reason: r),
                  ),
                  child: const Text('Restore'),
                ),
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Archive Match',
                  message: 'Archive this match?',
                  run: (r) => controller.archive(match, reason: r),
                ),
                child: const Text('Archive'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _editMetadata(
    BuildContext context,
    WidgetRef ref,
    ManagedMatch match,
  ) async {
    final title = TextEditingController(text: match.title);
    final venue = TextEditingController(text: match.venue);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Match Metadata'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: venue,
                  decoration: const InputDecoration(labelText: 'Venue'),
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
        ),
      );
      if (ok == true) {
        await ref.read(matchesListControllerProvider.notifier).saveMetadata(
              match,
              title: title.text.trim(),
              venue: venue.text.trim(),
            );
      }
    } finally {
      title.dispose();
      venue.dispose();
    }
  }
}
class _PlaceholderList extends StatelessWidget { const _PlaceholderList({required this.items}); final List<String> items; @override Widget build(BuildContext context) { final colors = context.adminColors; return Column(children: [for (final item in items) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(item), subtitle: Text('Coming soon', style: TextStyle(color: colors.textMuted, fontSize: 12)), trailing: Icon(Icons.lock_outline, size: 16, color: colors.textMuted))]); }}
class _SectionTitle extends StatelessWidget { const _SectionTitle(this.text); final String text; @override Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)); }
extension on String { String ifEmpty(String fallback) => isEmpty ? fallback : this; }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_permission.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/managed_broadcast.dart';
import '../../providers/broadcasts_providers.dart';
import 'broadcast_status_badge.dart';

class BroadcastDetailPanel extends ConsumerWidget {
  const BroadcastDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedManagedBroadcastProvider);
    final colors = context.adminColors;
    final canManage = ref
        .watch(permissionCheckerProvider)
        .can(AdminPermission.canManageBroadcast);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 460,
        child: async.when(
          loading: () => const CfLoadingState(message: 'Loading broadcast…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (broadcast) {
            if (broadcast == null) {
              return const Center(child: Text('Select a broadcast'));
            }
            return DefaultTabController(
              length: 8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Broadcast details',
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
                  const _MonitoringBanner(),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Match'),
                      Tab(text: 'Streaming'),
                      Tab(text: 'Health'),
                      Tab(text: 'Timeline'),
                      Tab(text: 'Logs'),
                      Tab(text: 'Reports'),
                      Tab(text: 'Audit Log'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OverviewTab(broadcast: broadcast, canManage: canManage),
                        _MatchTab(broadcast: broadcast),
                        _StreamingTab(broadcast: broadcast),
                        _HealthTab(broadcast: broadcast),
                        _TimelineTab(),
                        const _PlaceholderTab(
                          title: 'Logs',
                          message: 'Stream logs and ingest diagnostics coming soon.',
                        ),
                        const _PlaceholderTab(
                          title: 'Reports',
                          message: 'Broadcast quality reports coming soon.',
                        ),
                        const _AuditTab(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MonitoringBanner extends StatelessWidget {
  const _MonitoringBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 18, color: colors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Monitoring only — stream keys and stop controls are not available.',
              style: TextStyle(
                color: colors.info,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.broadcast, required this.canManage});

  final ManagedBroadcast broadcast;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = broadcast;
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _Hero(broadcast: b),
        const SizedBox(height: 16),
        _KeyValue('Match ID', b.id),
        _KeyValue('Record status', b.recordStatus.label),
        _KeyValue('Location', b.locationLabel),
        _KeyValue('Venue', b.venue.isEmpty ? '—' : b.venue),
        _KeyValue('Viewers', '${b.viewerCount}'),
        _KeyValue('Duration', b.durationLabel),
        _KeyValue(
          'Scheduled',
          b.scheduledAt == null ? '—' : dateFmt.format(b.scheduledAt!),
        ),
        _KeyValue(
          'Stream started',
          b.streamStartedAt == null ? '—' : dateFmt.format(b.streamStartedAt!),
        ),
        _KeyValue(
          'Last heartbeat',
          b.lastHeartbeatAt == null ? '—' : dateFmt.format(b.lastHeartbeatAt!),
        ),
        if (b.isSoftDeleted)
          _KeyValue(
            'Deleted at',
            b.deletedAt == null ? '—' : dateFmt.format(b.deletedAt!),
          ),
        if (canManage) ...[
          const SizedBox(height: 16),
          _Actions(broadcast: b),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.broadcast});

  final ManagedBroadcast broadcast;

  @override
  Widget build(BuildContext context) {
    final b = broadcast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          b.matchTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          b.teamsLabel,
          style: TextStyle(color: context.adminColors.textMuted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BroadcastStatusBadge(status: b.displayStatus),
            BroadcastHealthBadge(health: b.health),
            BroadcastPlatformBadge(platform: b.platform),
            BroadcastFeaturedBadge(featured: b.adminFeatured),
          ],
        ),
      ],
    );
  }
}

class _MatchTab extends StatelessWidget {
  const _MatchTab({required this.broadcast});

  final ManagedBroadcast broadcast;

  @override
  Widget build(BuildContext context) {
    final b = broadcast;
    final live = b.live;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Match'),
        const SizedBox(height: 8),
        _KeyValue('Match status', b.matchStatus.label),
        _KeyValue('Teams', b.teamsLabel),
        _KeyValue('Tournament', b.tournamentName ?? '—'),
        _KeyValue('Organizer', b.organizerName.isEmpty ? '—' : b.organizerName),
        _KeyValue('Scorer', b.scorerName.isEmpty ? '—' : b.scorerName),
        _KeyValue('Venue', b.venue.isEmpty ? '—' : b.venue),
        _KeyValue('Location', b.locationLabel),
        const SizedBox(height: 16),
        const _SectionTitle('Live score'),
        const SizedBox(height: 8),
        _KeyValue('Innings', b.currentInningsLabel),
        _KeyValue('Score', '${live.runs}/${live.wickets} (${live.oversText})'),
        _KeyValue('CRR', live.currentRunRate.toStringAsFixed(2)),
        if (live.strikerName != null)
          _KeyValue('Striker', live.strikerName!),
        if (live.nonStrikerName != null)
          _KeyValue('Non-striker', live.nonStrikerName!),
        if (live.currentBowlerName != null)
          _KeyValue('Bowler', live.currentBowlerName!),
      ],
    );
  }
}

class _StreamingTab extends StatelessWidget {
  const _StreamingTab({required this.broadcast});

  final ManagedBroadcast broadcast;

  @override
  Widget build(BuildContext context) {
    final b = broadcast;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Streaming'),
        const SizedBox(height: 8),
        _KeyValue('Platform', b.platform.label),
        _KeyValue('Stream status', b.streamStatus.label),
        _KeyValue('Orientation', b.orientation.isEmpty ? '—' : b.orientation),
        _KeyValue('WebRTC', b.webrtcEnabled ? 'Enabled' : 'Disabled'),
        if (b.cameraALabel.isNotEmpty)
          _KeyValue('Camera A', b.cameraALabel),
        if (b.cameraBLabel.isNotEmpty)
          _KeyValue('Camera B', b.cameraBLabel),
        const SizedBox(height: 12),
        _KeyValue(
          'Stream key',
          b.hasStreamKey ? b.maskedStreamKey : '—',
        ),
        _KeyValue(
          'RTMP host',
          b.hasRtmpUrl && b.rtmpHostMasked.isNotEmpty
              ? b.rtmpHostMasked
              : '—',
        ),
        const SizedBox(height: 12),
        _WatchUrlRow(
          label: 'Watch URL',
          url: b.watchUrl,
        ),
        if (b.secondaryWatchUrl != null) ...[
          const SizedBox(height: 8),
          _WatchUrlRow(
            label: 'Secondary watch URL',
            url: b.secondaryWatchUrl,
          ),
        ],
        if (b.youtubeVideoId != null) ...[
          const SizedBox(height: 8),
          _KeyValue('YouTube video ID', b.youtubeVideoId!),
        ],
        _KeyValue('Playback entries', '${b.playbackCount}'),
      ],
    );
  }
}

class _WatchUrlRow extends StatelessWidget {
  const _WatchUrlRow({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.adminColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(hasUrl ? url! : '—'),
        if (hasUrl) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(url!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Watch URL copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HealthTab extends StatelessWidget {
  const _HealthTab({required this.broadcast});

  final ManagedBroadcast broadcast;

  @override
  Widget build(BuildContext context) {
    final b = broadcast;
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Health'),
        const SizedBox(height: 8),
        Row(
          children: [
            BroadcastHealthBadge(health: b.health),
            const SizedBox(width: 12),
            BroadcastStatusBadge(status: b.displayStatus),
          ],
        ),
        const SizedBox(height: 16),
        _KeyValue('Viewer count', '${b.viewerCount}'),
        _KeyValue(
          'Last heartbeat',
          b.lastHeartbeatAt == null ? '—' : dateFmt.format(b.lastHeartbeatAt!),
        ),
        _KeyValue(
          'Stream started',
          b.streamStartedAt == null ? '—' : dateFmt.format(b.streamStartedAt!),
        ),
        _KeyValue(
          'Stream ended',
          b.endedAt == null ? '—' : dateFmt.format(b.endedAt!),
        ),
        _KeyValue('Duration', b.durationLabel),
        _KeyValue('WebRTC enabled', b.webrtcEnabled ? 'Yes' : 'No'),
        _KeyValue(
          'Has stream key configured',
          b.hasStreamKey ? 'Yes (masked)' : 'No',
        ),
        _KeyValue(
          'Has RTMP configured',
          b.hasRtmpUrl ? 'Yes (host masked)' : 'No',
        ),
      ],
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedBroadcastTimelineProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Timeline'),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (items) => items.isEmpty
              ? Text(
                  'No timeline events yet',
                  style: TextStyle(color: context.adminColors.textMuted),
                )
              : Column(
                  children: [
                    for (final item in items)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.timeline, size: 18),
                        title: Text(item.title),
                        subtitle: item.subtitle.isEmpty
                            ? null
                            : Text(item.subtitle),
                        trailing: Text(
                          DateFormat('MMM d HH:mm').format(item.occurredAt),
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

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedBroadcastAuditProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                    for (final item in items.take(30))
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

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _SectionTitle(title),
        const SizedBox(height: 8),
        Text(message, style: TextStyle(color: context.adminColors.textMuted)),
        const SizedBox(height: 12),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(
            'Coming soon',
            style: TextStyle(color: context.adminColors.textMuted, fontSize: 12),
          ),
          trailing: Icon(
            Icons.lock_outline,
            size: 16,
            color: context.adminColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.broadcast});

  final ManagedBroadcast broadcast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(broadcastsListControllerProvider.notifier);
    final b = broadcast;

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
              onPressed: () => confirmAction(
                title: b.adminFeatured ? 'Unfeature' : 'Feature',
                message: b.adminFeatured
                    ? 'Remove broadcast feature?'
                    : 'Feature this broadcast?',
                run: (r) => controller.setFeatured(
                  b,
                  !b.adminFeatured,
                  reason: r,
                ),
              ),
              child: Text(b.adminFeatured ? 'Unfeature' : 'Feature'),
            ),
            if (!b.isSoftDeleted) ...[
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Soft-delete',
                  message:
                      'Soft-delete this broadcast record? Stream history stays intact.',
                  danger: true,
                  run: (r) => controller.softDelete(b, reason: r),
                ),
                child: const Text('Delete'),
              ),
            ] else
              OutlinedButton(
                onPressed: () => confirmAction(
                  title: 'Restore',
                  message: 'Restore this broadcast record?',
                  run: (r) => controller.restore(b, reason: r),
                ),
                child: const Text('Restore'),
              ),
            OutlinedButton(
              onPressed: () => confirmAction(
                title: 'Archive',
                message: 'Archive this broadcast record?',
                run: (r) => controller.archive(b, reason: r),
              ),
              child: const Text('Archive'),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: context.adminColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
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

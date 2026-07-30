import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_notification.dart';
import '../../models/notification_enums.dart';
import '../../providers/notifications_providers.dart';
import 'notification_status_badge.dart';

class NotificationDetailPanel extends ConsumerWidget {
  const NotificationDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedNotificationCampaignProvider);
    final colors = context.adminColors;
    final controller = ref.read(notificationsHubControllerProvider.notifier);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 460,
        child: async.when(
          loading: () =>
              const CfLoadingState(message: 'Loading notification…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (campaign) {
            if (campaign == null) {
              return const Center(child: Text('Select a notification'));
            }
            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notification details',
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
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Delivery'),
                      Tab(text: 'Audience'),
                      Tab(text: 'Audit'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _OverviewTab(
                          campaign: campaign,
                          controller: controller,
                        ),
                        _DeliveryTab(campaign: campaign),
                        _AudienceTab(campaign: campaign),
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

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.campaign,
    required this.controller,
  });

  final ManagedNotificationCampaign campaign;
  final NotificationsHubController controller;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          c.displayTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (c.subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            c.subtitle,
            style: TextStyle(color: context.adminColors.textMuted),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            NotificationStatusBadge(status: c.status),
            NotificationTypeBadge(type: c.type),
            NotificationAudienceBadge(audience: c.audience),
          ],
        ),
        const SizedBox(height: 16),
        if (c.body.isNotEmpty) ...[
          const _SectionTitle('Body'),
          const SizedBox(height: 4),
          Text(c.body),
          const SizedBox(height: 16),
        ],
        if (c.imageUrl.isNotEmpty) ...[
          const _SectionTitle('Image'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              c.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, e, st) => const SizedBox(
                height: 48,
                child: Center(child: Text('Image unavailable')),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _KeyValue('Deep link', c.deepLink.isEmpty ? '—' : c.deepLink),
        _KeyValue('Action button', c.actionButtonText.isEmpty ? '—' : c.actionButtonText),
        _KeyValue('Priority', c.priority.label),
        _KeyValue('Sound', c.sound.label),
        _KeyValue(
          'Created',
          c.createdAt == null ? '—' : dateFmt.format(c.createdAt!),
        ),
        _KeyValue(
          'Scheduled',
          c.scheduledAt == null ? '—' : dateFmt.format(c.scheduledAt!),
        ),
        _KeyValue(
          'Sent',
          c.sentAt == null ? '—' : dateFmt.format(c.sentAt!),
        ),
        if (c.isCampaign) ...[
          _KeyValue('Campaign name', c.campaignName.isEmpty ? '—' : c.campaignName),
        ],
        const SizedBox(height: 16),
        _Actions(campaign: c, controller: controller),
      ],
    );
  }
}

class _DeliveryTab extends StatelessWidget {
  const _DeliveryTab({required this.campaign});

  final ManagedNotificationCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Delivery metrics'),
        const SizedBox(height: 8),
        _KeyValue('Recipients', '${c.recipientCount}'),
        _KeyValue('Sent', '${c.sentCount}'),
        _KeyValue('Delivered', '${c.deliveredCount}'),
        _KeyValue('Opened', '${c.openedCount}'),
        _KeyValue('Clicked', '${c.clickedCount}'),
        _KeyValue('Failed', '${c.failedCount}'),
        _KeyValue(
          'Open rate',
          c.deliveredCount > 0
              ? '${(c.openRate * 100).toStringAsFixed(1)}%'
              : '—',
        ),
        _KeyValue(
          'Click rate',
          c.deliveredCount > 0
              ? '${(c.clickRate * 100).toStringAsFixed(1)}%'
              : '—',
        ),
        if (c.deliveryNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionTitle('Delivery note'),
          const SizedBox(height: 4),
          Text(c.deliveryNote),
        ],
        const SizedBox(height: 16),
        const _SectionTitle('Platforms'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final p in c.platforms)
              Chip(label: Text(p.label), visualDensity: VisualDensity.compact),
          ],
        ),
        const SizedBox(height: 16),
        _KeyValue('Schedule mode', c.scheduleMode.label),
        _KeyValue('Recurrence', c.recurrence.label),
        _KeyValue('Timezone', c.timezone),
      ],
    );
  }
}

class _AudienceTab extends StatelessWidget {
  const _AudienceTab({required this.campaign});

  final ManagedNotificationCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Audience'),
        const SizedBox(height: 8),
        NotificationAudienceBadge(audience: c.audience),
        const SizedBox(height: 12),
        _KeyValue('Label', c.audienceLabel.isEmpty ? '—' : c.audienceLabel),
        if (c.country.isNotEmpty) _KeyValue('Country', c.country),
        if (c.stateProvince.isNotEmpty)
          _KeyValue('State / Province', c.stateProvince),
        if (c.city.isNotEmpty) _KeyValue('City', c.city),
        if (c.audienceIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionTitle('Target IDs'),
          const SizedBox(height: 4),
          Text(
            '${c.audienceIds.length} target(s) configured',
            style: TextStyle(color: context.adminColors.textMuted),
          ),
          const SizedBox(height: 8),
          for (final id in c.audienceIds.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                id.length > 16 ? '${id.substring(0, 16)}…' : id,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          if (c.audienceIds.length > 20)
            Text(
              '… and ${c.audienceIds.length - 20} more',
              style: TextStyle(color: context.adminColors.textMuted),
            ),
        ],
      ],
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationAuditProvider);
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

class _Actions extends StatelessWidget {
  const _Actions({
    required this.campaign,
    required this.controller,
  });

  final ManagedNotificationCampaign campaign;
  final NotificationsHubController controller;

  Future<void> _confirmAction(
    BuildContext context, {
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
            variant: danger ? CfButtonVariant.danger : CfButtonVariant.primary,
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

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final isDraft = c.status == ManagedNotificationStatus.draft;
    final isScheduled = c.status == ManagedNotificationStatus.scheduled;
    final canSend = isDraft ||
        c.status == ManagedNotificationStatus.failed ||
        c.status == ManagedNotificationStatus.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canSend)
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Send now',
                  message: 'Send this notification immediately?',
                  run: (r) => controller.sendNow(c, reason: r),
                ),
                child: const Text('Send / Queue'),
              ),
            if (isDraft || isScheduled)
              OutlinedButton(
                onPressed: () async {
                  final at = await showDatePicker(
                    context: context,
                    initialDate: c.scheduledAt ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (at == null || !context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                      c.scheduledAt ?? DateTime.now(),
                    ),
                  );
                  if (time == null || !context.mounted) return;
                  final scheduled = DateTime(
                    at.year,
                    at.month,
                    at.day,
                    time.hour,
                    time.minute,
                  );
                  await controller.schedule(
                    c,
                    at: scheduled,
                    recurrence: c.recurrence,
                    timezone: c.timezone,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scheduled')),
                    );
                  }
                },
                child: const Text('Schedule'),
              ),
            if (isScheduled)
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Cancel schedule',
                  message: 'Cancel this scheduled notification?',
                  run: (r) => controller.cancel(c, reason: r),
                ),
                child: const Text('Cancel'),
              ),
            OutlinedButton(
              onPressed: () => _confirmAction(
                context,
                title: 'Duplicate',
                message: 'Create a copy of this notification as a draft?',
                run: (r) => controller.duplicate(c, reason: r),
              ),
              child: const Text('Duplicate'),
            ),
            if (c.status != ManagedNotificationStatus.archived)
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Archive',
                  message: 'Archive this notification?',
                  run: (r) => controller.archive(c, reason: r),
                ),
                child: const Text('Archive'),
              ),
            if (isDraft)
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Delete draft',
                  message: 'Permanently delete this draft?',
                  danger: true,
                  run: (r) => controller.deleteDraft(c, reason: r),
                ),
                child: const Text('Delete draft'),
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
          Expanded(child: SelectableText(value)),
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

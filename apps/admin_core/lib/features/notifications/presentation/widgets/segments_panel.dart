import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_notification.dart';
import '../../models/notification_enums.dart';
import '../../providers/notifications_providers.dart';
import 'notification_status_badge.dart';

class SegmentsPanel extends ConsumerWidget {
  const SegmentsPanel({
    super.key,
    required this.segments,
    required this.isLoading,
  });

  final List<ManagedNotificationSegment> segments;
  final bool isLoading;

  Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref, {
    ManagedNotificationSegment? existing,
  }) async {
    final controller = ref.read(notificationsHubControllerProvider.notifier);
    final isCreate = existing == null;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final countCtrl = TextEditingController(
      text: '${existing?.estimatedCount ?? 0}',
    );
    var audience =
        existing?.audience ?? ManagedNotificationAudience.everyone;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isCreate ? 'Create segment' : 'Edit segment'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedNotificationAudience>(
                    value: audience,
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: [
                      for (final a in ManagedNotificationAudience.values)
                        DropdownMenuItem(value: a, child: Text(a.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => audience = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Estimated count',
                    ),
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
              label: isCreate ? 'Create' : 'Save',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final segment = ManagedNotificationSegment(
      id: existing?.id ?? '',
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim(),
      audience: audience,
      estimatedCount: int.tryParse(countCtrl.text.trim()) ?? 0,
      filters: existing?.filters ?? const {},
    );

    await controller.saveSegment(segment, create: isCreate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isCreate ? 'Segment created' : 'Segment saved')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ManagedNotificationSegment s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete segment'),
        content: Text('Delete "${s.name}"?'),
        actions: [
          CfButton(
            label: 'Cancel',
            variant: CfButtonVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
          ),
          CfButton(
            label: 'Delete',
            variant: CfButtonVariant.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(notificationsHubControllerProvider.notifier).deleteSegment(s);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Segment deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;

    if (isLoading && segments.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading segments…'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: CfButton(
            label: 'Create segment',
            icon: Icons.add,
            onPressed: () => _showDialog(context, ref),
          ),
        ),
        const SizedBox(height: 16),
        if (!isLoading && segments.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 240,
              child: CfEmptyState(
                icon: Icons.group_outlined,
                title: 'No user segments',
                message: 'Define audience segments for targeted notifications.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < segments.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  ListTile(
                    title: Text(
                      segments[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (segments[i].description.isNotEmpty)
                          Text(segments[i].description),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            NotificationAudienceBadge(
                              audience: segments[i].audience,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '~${segments[i].estimatedCount} users',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _showDialog(
                            context,
                            ref,
                            existing: segments[i],
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(context, ref, segments[i]),
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: colors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

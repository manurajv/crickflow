import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_notification.dart';
import '../../providers/notifications_providers.dart';

class AnnouncementsPanel extends ConsumerWidget {
  const AnnouncementsPanel({
    super.key,
    required this.announcements,
    required this.isLoading,
  });

  final List<ManagedAnnouncement> announcements;
  final bool isLoading;

  Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref, {
    ManagedAnnouncement? existing,
  }) async {
    final controller = ref.read(notificationsHubControllerProvider.notifier);
    final isCreate = existing == null;

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final buttonCtrl = TextEditingController(text: existing?.buttonText ?? '');
    final redirectActionCtrl =
        TextEditingController(text: existing?.redirectAction ?? 'none');
    final redirectUrlCtrl =
        TextEditingController(text: existing?.redirectUrl ?? '');
    final priorityCtrl = TextEditingController(
      text: '${existing?.priority ?? 0}',
    );
    var active = existing?.active ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isCreate ? 'Create announcement' : 'Edit announcement'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageCtrl,
                    decoration: const InputDecoration(labelText: 'Image URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: buttonCtrl,
                    decoration: const InputDecoration(labelText: 'Button text'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: redirectActionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Redirect action',
                      hintText: 'none',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: redirectUrlCtrl,
                    decoration: const InputDecoration(labelText: 'Redirect URL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priorityCtrl,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
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

    final announcement = ManagedAnnouncement(
      id: existing?.id ?? '',
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim(),
      imageUrl: imageCtrl.text.trim(),
      buttonText: buttonCtrl.text.trim(),
      redirectAction: redirectActionCtrl.text.trim().isEmpty
          ? 'none'
          : redirectActionCtrl.text.trim(),
      redirectUrl: redirectUrlCtrl.text.trim(),
      priority: int.tryParse(priorityCtrl.text.trim()) ?? 0,
      active: active,
      kind: 'announcement',
    );

    await controller.saveAnnouncement(announcement, create: isCreate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCreate ? 'Announcement created' : 'Announcement saved'),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ManagedAnnouncement a,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete announcement'),
        content: Text('Delete "${a.title}"?'),
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
    await ref.read(notificationsHubControllerProvider.notifier).deleteAnnouncement(a);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final dateFmt = DateFormat('MMM d, yyyy');

    if (isLoading && announcements.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading announcements…'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: CfButton(
            label: 'Create announcement',
            icon: Icons.add,
            onPressed: () => _showDialog(context, ref),
          ),
        ),
        const SizedBox(height: 16),
        if (!isLoading && announcements.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 240,
              child: CfEmptyState(
                icon: Icons.campaign_outlined,
                title: 'No announcements',
                message: 'Create in-app announcements for users to see on launch.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < announcements.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  ListTile(
                    title: Text(
                      announcements[i].title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (announcements[i].description.isNotEmpty)
                          Text(
                            announcements[i].description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Priority ${announcements[i].priority} · '
                          '${announcements[i].active ? 'Active' : 'Inactive'} · '
                          '${announcements[i].createdAt != null ? dateFmt.format(announcements[i].createdAt!) : '—'}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
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
                            existing: announcements[i],
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(context, ref, announcements[i]),
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

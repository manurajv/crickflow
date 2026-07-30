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

class TemplatesPanel extends ConsumerWidget {
  const TemplatesPanel({
    super.key,
    required this.templates,
    required this.isLoading,
  });

  final List<ManagedNotificationTemplate> templates;
  final bool isLoading;

  Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref, {
    ManagedNotificationTemplate? existing,
  }) async {
    final controller = ref.read(notificationsHubControllerProvider.notifier);
    final isCreate = existing == null;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    final deepLinkCtrl = TextEditingController(text: existing?.deepLink ?? '');
    var type = existing?.type ?? ManagedNotificationType.system;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isCreate ? 'Create template' : 'Edit template'),
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
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    decoration: const InputDecoration(labelText: 'Body'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deepLinkCtrl,
                    decoration: const InputDecoration(labelText: 'Deep link'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedNotificationType>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final t in ManagedNotificationType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => type = v);
                    },
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

    final template = ManagedNotificationTemplate(
      id: existing?.id ?? '',
      name: nameCtrl.text.trim(),
      title: titleCtrl.text.trim(),
      body: bodyCtrl.text.trim(),
      type: type,
      deepLink: deepLinkCtrl.text.trim(),
    );

    await controller.saveTemplate(template, create: isCreate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isCreate ? 'Template created' : 'Template saved')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ManagedNotificationTemplate t,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template'),
        content: Text('Delete "${t.name}"?'),
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
    await ref.read(notificationsHubControllerProvider.notifier).deleteTemplate(t);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;

    if (isLoading && templates.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading templates…'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: CfButton(
            label: 'Create template',
            icon: Icons.add,
            onPressed: () => _showDialog(context, ref),
          ),
        ),
        const SizedBox(height: 16),
        if (!isLoading && templates.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 240,
              child: CfEmptyState(
                icon: Icons.description_outlined,
                title: 'No templates',
                message: 'Save reusable notification templates for faster sends.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < templates.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  ListTile(
                    title: Text(
                      templates[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (templates[i].title.isNotEmpty)
                          Text(templates[i].title),
                        const SizedBox(height: 4),
                        NotificationTypeBadge(type: templates[i].type),
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
                            existing: templates[i],
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(context, ref, templates[i]),
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

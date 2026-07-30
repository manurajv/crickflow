import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/ads_enums.dart';
import '../../models/managed_ads.dart';
import '../../providers/ads_providers.dart';
import 'ad_status_badge.dart';

class SponsoredPanel extends ConsumerWidget {
  const SponsoredPanel({
    super.key,
    required this.items,
    required this.isLoading,
  });

  final List<ManagedSponsoredContent> items;
  final bool isLoading;

  Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref, {
    ManagedSponsoredContent? existing,
  }) async {
    final controller = ref.read(adsHubControllerProvider.notifier);
    final isCreate = existing == null;

    final entityIdCtrl = TextEditingController(text: existing?.entityId ?? '');
    final entityLabelCtrl =
        TextEditingController(text: existing?.entityLabel ?? '');
    final sponsorCtrl =
        TextEditingController(text: existing?.sponsorName ?? '');
    final campaignIdCtrl =
        TextEditingController(text: existing?.campaignId ?? '');
    final campaignNameCtrl =
        TextEditingController(text: existing?.campaignName ?? '');
    final priorityCtrl =
        TextEditingController(text: '${existing?.priority ?? 0}');
    var entityType =
        existing?.entityType ?? ManagedSponsoredEntityType.tournament;
    var status = existing?.status ?? ManagedAdStatus.active;
    var featuredBadge = existing?.featuredBadge ?? true;
    DateTime? startDate = existing?.startDate;
    DateTime? endDate = existing?.endDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isCreate ? 'Create sponsored content' : 'Edit sponsored'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ManagedSponsoredEntityType>(
                    value: entityType,
                    decoration: const InputDecoration(labelText: 'Entity type'),
                    items: [
                      for (final t in ManagedSponsoredEntityType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => entityType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: entityIdCtrl,
                    decoration: const InputDecoration(labelText: 'Entity ID *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: entityLabelCtrl,
                    decoration: const InputDecoration(labelText: 'Entity label'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sponsorCtrl,
                    decoration: const InputDecoration(labelText: 'Sponsor name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: campaignIdCtrl,
                    decoration: const InputDecoration(labelText: 'Campaign ID'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: campaignNameCtrl,
                    decoration: const InputDecoration(labelText: 'Campaign name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priorityCtrl,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ManagedAdStatus>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final s in [
                        ManagedAdStatus.active,
                        ManagedAdStatus.scheduled,
                        ManagedAdStatus.paused,
                        ManagedAdStatus.archived,
                      ])
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => status = v);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Featured badge'),
                    value: featuredBadge,
                    onChanged: (v) => setDialogState(() => featuredBadge = v),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 3)),
                            );
                            if (picked != null) {
                              setDialogState(() => startDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            startDate == null
                                ? 'Start date'
                                : '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 3)),
                            );
                            if (picked != null) {
                              setDialogState(() => endDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            endDate == null
                                ? 'End date'
                                : '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                    ],
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

    final item = ManagedSponsoredContent(
      id: existing?.id ?? '',
      entityType: entityType,
      entityId: entityIdCtrl.text.trim(),
      entityLabel: entityLabelCtrl.text.trim(),
      sponsorName: sponsorCtrl.text.trim(),
      campaignId: campaignIdCtrl.text.trim().isEmpty
          ? null
          : campaignIdCtrl.text.trim(),
      campaignName: campaignNameCtrl.text.trim(),
      startDate: startDate,
      endDate: endDate,
      priority: int.tryParse(priorityCtrl.text.trim()) ?? 0,
      featuredBadge: featuredBadge,
      status: status,
    );

    await controller.saveSponsored(item, create: isCreate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCreate ? 'Sponsored content created' : 'Saved'),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ManagedSponsoredContent item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete sponsored content'),
        content: Text(
          'Delete sponsorship for "${item.entityLabel.isNotEmpty ? item.entityLabel : item.entityId}"?',
        ),
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
    await ref.read(adsHubControllerProvider.notifier).deleteSponsored(item);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sponsored content deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;

    if (isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading sponsored content…'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: CfButton(
            label: 'Create sponsored',
            icon: Icons.add,
            onPressed: () => _showDialog(context, ref),
          ),
        ),
        const SizedBox(height: 16),
        if (!isLoading && items.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 240,
              child: CfEmptyState(
                icon: Icons.star_outline,
                title: 'No sponsored content',
                message: 'Link sponsors to tournaments, teams, and posts.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  ListTile(
                    title: Text(
                      items[i].entityLabel.isNotEmpty
                          ? items[i].entityLabel
                          : items[i].entityId,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${items[i].entityType.label} · ${items[i].entityId}'),
                        if (items[i].sponsorName.isNotEmpty)
                          Text('Sponsor: ${items[i].sponsorName}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            AdStatusBadge(status: items[i].status),
                            if (items[i].featuredBadge) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: const Text('Featured'),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
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
                            existing: items[i],
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(context, ref, items[i]),
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

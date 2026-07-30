import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_ads.dart';
import '../../providers/ads_providers.dart';

class AdvertisersPanel extends ConsumerWidget {
  const AdvertisersPanel({
    super.key,
    required this.advertisers,
    required this.isLoading,
  });

  final List<ManagedAdvertiser> advertisers;
  final bool isLoading;

  Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref, {
    ManagedAdvertiser? existing,
  }) async {
    final controller = ref.read(adsHubControllerProvider.notifier);
    final isCreate = existing == null;

    final companyCtrl = TextEditingController(text: existing?.companyName ?? '');
    final logoCtrl = TextEditingController(text: existing?.logoUrl ?? '');
    final contactCtrl =
        TextEditingController(text: existing?.contactPerson ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final websiteCtrl = TextEditingController(text: existing?.website ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCreate ? 'Create advertiser' : 'Edit advertiser'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: companyCtrl,
                  decoration: const InputDecoration(labelText: 'Company name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: logoCtrl,
                  decoration: const InputDecoration(labelText: 'Logo URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Contact person'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: websiteCtrl,
                  decoration: const InputDecoration(labelText: 'Website'),
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
    );

    if (ok != true) return;

    final advertiser = ManagedAdvertiser(
      id: existing?.id ?? '',
      companyName: companyCtrl.text.trim(),
      logoUrl: logoCtrl.text.trim(),
      contactPerson: contactCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      website: websiteCtrl.text.trim(),
      activeAds: existing?.activeAds ?? 0,
      campaignCount: existing?.campaignCount ?? 0,
      estimatedRevenue: existing?.estimatedRevenue ?? 0,
    );

    await controller.saveAdvertiser(advertiser, create: isCreate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCreate ? 'Advertiser created' : 'Advertiser saved'),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ManagedAdvertiser a,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete advertiser'),
        content: Text('Delete "${a.companyName}"?'),
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
    await ref.read(adsHubControllerProvider.notifier).deleteAdvertiser(a);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advertiser deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final revenueFmt = NumberFormat.compactCurrency(symbol: '\$');

    if (isLoading && advertisers.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading advertisers…'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: CfButton(
            label: 'Create advertiser',
            icon: Icons.add,
            onPressed: () => _showDialog(context, ref),
          ),
        ),
        const SizedBox(height: 16),
        if (!isLoading && advertisers.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 240,
              child: CfEmptyState(
                icon: Icons.business_outlined,
                title: 'No advertisers',
                message: 'Add advertisers to associate with ad campaigns.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < advertisers.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  ListTile(
                    isThreeLine: true,
                    leading: _AdvertiserAvatar(advertiser: advertisers[i]),
                    title: Text(
                      advertisers[i].companyName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (advertisers[i].contactPerson.isNotEmpty)
                          advertisers[i].contactPerson,
                        if (advertisers[i].email.isNotEmpty)
                          advertisers[i].email,
                        '${advertisers[i].activeAds} active · ${advertisers[i].campaignCount} campaigns · ${revenueFmt.format(advertisers[i].estimatedRevenue)}',
                      ].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _showDialog(
                            context,
                            ref,
                            existing: advertisers[i],
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(context, ref, advertisers[i]),
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

class _AdvertiserAvatar extends StatelessWidget {
  const _AdvertiserAvatar({required this.advertiser});

  final ManagedAdvertiser advertiser;

  @override
  Widget build(BuildContext context) {
    final initial = advertiser.companyName.isNotEmpty
        ? advertiser.companyName[0].toUpperCase()
        : '?';
    if (advertiser.logoUrl.isEmpty) {
      return CircleAvatar(child: Text(initial));
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: Image.network(
          advertiser.logoUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Text(initial),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/ads_enums.dart';
import '../../models/managed_ads.dart';
import '../../providers/ads_providers.dart';
import 'ad_status_badge.dart';

class AdDetailPanel extends ConsumerWidget {
  const AdDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(selectedAdCampaignProvider);
    final colors = context.adminColors;
    final controller = ref.read(adsHubControllerProvider.notifier);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 460,
        child: async.when(
          loading: () => const CfLoadingState(message: 'Loading advertisement…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (campaign) {
            if (campaign == null) {
              return const Center(child: Text('Select an advertisement'));
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
                            'Advertisement details',
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
                      Tab(text: 'Targeting'),
                      Tab(text: 'Stats'),
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
                        _TargetingTab(campaign: campaign),
                        _StatsTab(campaign: campaign),
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

  final ManagedAdCampaign campaign;
  final AdsHubController controller;

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
        if (c.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            c.description,
            style: TextStyle(color: context.adminColors.textMuted),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AdStatusBadge(status: c.status),
            AdMediaTypeBadge(mediaType: c.mediaType),
            AdCampaignTypeBadge(campaignType: c.campaignType),
            if (c.featured)
              Chip(
                label: const Text('Featured'),
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    context.adminColors.warning.withValues(alpha: 0.12),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (c.bannerUrl.isNotEmpty) ...[
          const _SectionTitle('Banner'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              c.bannerUrl,
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
        _KeyValue('Campaign', c.campaignName.isEmpty ? '—' : c.campaignName),
        _KeyValue('Advertiser',
            c.advertiserName.isEmpty ? '—' : c.advertiserName),
        _KeyValue('Destination',
            c.destinationUrl.isEmpty ? '—' : c.destinationUrl),
        _KeyValue('Button text', c.buttonText),
        _KeyValue('Placements', c.placementLabel),
        _KeyValue('Priority', '${c.priority}'),
        _KeyValue('Weight', '${c.weight}'),
        _KeyValue(
          'Start',
          c.startDate == null ? '—' : dateFmt.format(c.startDate!),
        ),
        _KeyValue(
          'End',
          c.endDate == null ? '—' : dateFmt.format(c.endDate!),
        ),
        _KeyValue(
          'Created',
          c.createdAt == null ? '—' : dateFmt.format(c.createdAt!),
        ),
        if (c.rejectionReason.isNotEmpty)
          _KeyValue('Rejection reason', c.rejectionReason),
        const SizedBox(height: 16),
        _Actions(campaign: c, controller: controller),
      ],
    );
  }
}

class _TargetingTab extends StatelessWidget {
  const _TargetingTab({required this.campaign});

  final ManagedAdCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Geographic targeting'),
        const SizedBox(height: 8),
        _KeyValue('Country', c.country.isEmpty ? '—' : c.country),
        _KeyValue('State / Province',
            c.stateProvince.isEmpty ? '—' : c.stateProvince),
        _KeyValue('City', c.city.isEmpty ? '—' : c.city),
        _KeyValue('Language', c.language.isEmpty ? '—' : c.language),
        const SizedBox(height: 16),
        const _SectionTitle('Cricket targeting'),
        const SizedBox(height: 8),
        _KeyValue('Match type', c.matchType.isEmpty ? '—' : c.matchType),
        _KeyValue('Ball type', c.ballType.isEmpty ? '—' : c.ballType),
        _KeyValue(
          'Tournament ID',
          c.tournamentId ?? '—',
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Placements'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in c.placements)
              Chip(
                label: Text(p.label),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.campaign});

  final ManagedAdCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final revenueFmt = NumberFormat.compactCurrency(symbol: '\$');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SectionTitle('Performance'),
        const SizedBox(height: 8),
        _KeyValue('Impressions', NumberFormat.decimalPattern().format(c.impressions)),
        _KeyValue('Clicks', NumberFormat.decimalPattern().format(c.clicks)),
        _KeyValue(
          'CTR',
          c.impressions > 0
              ? '${(c.ctr * 100).toStringAsFixed(2)}%'
              : '—',
        ),
        _KeyValue('Est. revenue', revenueFmt.format(c.estimatedRevenue)),
        if (c.homePromotionId != null)
          _KeyValue('Home promotion ID', c.homePromotionId!),
      ],
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adsAuditProvider);
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

  final ManagedAdCampaign campaign;
  final AdsHubController controller;

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function(String? reason) run,
    bool danger = false,
    String? rejectionReason,
  }) async {
    final reasonController = TextEditingController(text: rejectionReason);
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
              decoration: InputDecoration(
                labelText: rejectionReason != null
                    ? 'Rejection reason'
                    : 'Reason (optional)',
              ),
              maxLines: rejectionReason != null ? 3 : 1,
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
    final isPending = c.status == ManagedAdStatus.pendingApproval;
    final isActive = c.status == ManagedAdStatus.active;
    final isPaused = c.status == ManagedAdStatus.paused;
    final isDraft = c.status == ManagedAdStatus.draft;
    final canArchive = c.status != ManagedAdStatus.archived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (isPending) ...[
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Approve',
                  message: 'Approve this advertisement for delivery?',
                  run: (r) => controller.setStatus(
                    c,
                    ManagedAdStatus.approved,
                    reason: r,
                  ),
                ),
                child: const Text('Approve'),
              ),
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Reject',
                  message: 'Reject this advertisement?',
                  rejectionReason: '',
                  run: (r) => controller.setStatus(
                    c,
                    ManagedAdStatus.rejected,
                    reason: r,
                    rejectionReason: r,
                  ),
                ),
                child: const Text('Reject'),
              ),
            ],
            if (isActive)
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Pause',
                  message: 'Pause this active advertisement?',
                  run: (r) => controller.setStatus(
                    c,
                    ManagedAdStatus.paused,
                    reason: r,
                  ),
                ),
                child: const Text('Pause'),
              ),
            if (isPaused)
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Resume',
                  message: 'Resume this paused advertisement?',
                  run: (r) => controller.setStatus(
                    c,
                    ManagedAdStatus.active,
                    reason: r,
                  ),
                ),
                child: const Text('Resume'),
              ),
            if (canArchive)
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Archive',
                  message: 'Archive this advertisement?',
                  run: (r) => controller.setStatus(
                    c,
                    ManagedAdStatus.archived,
                    reason: r,
                  ),
                ),
                child: const Text('Archive'),
              ),
            OutlinedButton(
              onPressed: () => _confirmAction(
                context,
                title: 'Duplicate',
                message: 'Create a copy of this advertisement as a draft?',
                run: (r) => controller.duplicate(c, reason: r),
              ),
              child: const Text('Duplicate'),
            ),
            OutlinedButton(
              onPressed: () => controller.setFeatured(c, !c.featured),
              child: Text(c.featured ? 'Unfeature' : 'Feature'),
            ),
            if (isDraft)
              OutlinedButton(
                onPressed: () => _confirmAction(
                  context,
                  title: 'Delete',
                  message: 'Permanently delete this draft advertisement?',
                  danger: true,
                  run: (r) => controller.delete(c, reason: r),
                ),
                child: const Text('Delete'),
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

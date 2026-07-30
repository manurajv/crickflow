import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_card.dart';
import '../../../shared/widgets/cf_empty_state.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../../shared/widgets/cf_search_bar.dart';
import '../../../shared/widgets/cf_stat_tile.dart';
import '../../../shared/widgets/cf_status_badge.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/managed_revenue.dart';
import '../models/revenue_enums.dart';
import '../models/revenue_filters.dart';
import '../providers/revenue_providers.dart';

class RevenueScreen extends ConsumerStatefulWidget {
  const RevenueScreen({super.key});

  @override
  ConsumerState<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends ConsumerState<RevenueScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'Platform',
        'Revenue',
      ];
      ref.read(revenueHubControllerProvider.notifier).ensureBootstrapped();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(revenueHubControllerProvider);
    final controller = ref.read(revenueHubControllerProvider.notifier);
    final isSuperAdmin =
        ref.watch(adminAppTypeProvider) == AdminAppType.superAdmin;
    final money = NumberFormat.compactCurrency(symbol: '\$');

    return PermissionGate(
      permission: AdminPermission.canAccessGlobalData,
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Revenue Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Estimates & architecture only — no payment gateway, no card data'
                  : 'Super Admin only',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in RevenueHubSection.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: state.section == s,
                        onSelected: (_) async {
                          await controller.setSection(s);
                          ref.read(breadcrumbProvider.notifier).state = [
                            'Platform',
                            'Revenue',
                            s.label,
                          ];
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CfSearchBar(
              controller: _search,
              hintText: 'Search title, stream, source id…',
              onChanged: (q) {
                controller.setQuery(q);
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  controller.refresh();
                });
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                CfButton(
                  label: state.filters.hasActiveFilters ? 'Filters •' : 'Filters',
                  variant: CfButtonVariant.secondary,
                  onPressed: () async {
                    final next = await _showFilters(context, state.filters);
                    if (next != null) await controller.applyFilters(next);
                  },
                ),
                const SizedBox(width: 8),
                CfButton(
                  label: state.isLoading ? 'Refreshing…' : 'Refresh',
                  variant: CfButtonVariant.ghost,
                  onPressed:
                      state.isLoading ? null : () => controller.refresh(force: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: Text(state.error!)),
                        CfButton(
                          label: 'Retry',
                          onPressed: () => controller.refresh(force: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (state.isLoading && state.entries.isEmpty)
              const SizedBox(
                height: 240,
                child: CfLoadingState(message: 'Loading Revenue Center…'),
              )
            else ...[
              if (state.section == RevenueHubSection.dashboard ||
                  state.section == RevenueHubSection.adsRevenue ||
                  state.section == RevenueHubSection.sponsorships) ...[
                _SummaryCards(summary: state.summary, money: money),
                const SizedBox(height: 16),
              ],
              _sectionBody(state: state, money: money),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionBody({
    required RevenueHubState state,
    required NumberFormat money,
  }) {
    switch (state.section) {
      case RevenueHubSection.dashboard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CfCard(
              child: Text(state.summary.readinessNote),
            ),
            const SizedBox(height: 16),
            _EntriesTable(
              title: 'Recent estimates',
              entries: state.entries.take(20).toList(),
              money: money,
            ),
          ],
        );
      case RevenueHubSection.adsRevenue:
        return _EntriesTable(
          title: 'Ads revenue estimates',
          entries: state.entries
              .where((e) => e.stream == RevenueStreamKind.ads)
              .toList(),
          money: money,
        );
      case RevenueHubSection.sponsorships:
        return _EntriesTable(
          title: 'Sponsorship estimates',
          entries: state.entries
              .where((e) => e.stream == RevenueStreamKind.sponsorship)
              .toList(),
          money: money,
        );
      case RevenueHubSection.subscriptions:
        return const CfCard(
          child: Text(
            'Subscriptions architecture is ready for Stripe / Play Billing / '
            'App Store Connect. No live billing is connected from this UI.',
          ),
        );
      case RevenueHubSection.transactions:
        return _EntriesTable(
          title: 'Transaction / estimate ledger',
          entries: state.entries,
          money: money,
        );
      case RevenueHubSection.payouts:
        return const CfCard(
          child: Text(
            'Payout workflows (organizer shares, affiliate, refunds) are reserved '
            'for a future Cloud Functions + payment provider integration. '
            'No payouts are executed from the admin client.',
          ),
        );
      case RevenueHubSection.reports:
        return CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'CSV / Excel / PDF export of revenue estimates will plug into '
                'AdminExportLocalizer later. Current source: ads + sponsored '
                'metadata and optional admin_revenue_ledger rows.',
              ),
            ],
          ),
        );
      case RevenueHubSection.integrations:
        return Column(
          children: [
            for (final i in state.integrations)
              CfCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    i.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(i.description),
                  trailing: CfStatusBadge(
                    label: i.statusLabel,
                    tone: i.ready ? CfBadgeTone.success : CfBadgeTone.neutral,
                  ),
                ),
              ),
          ],
        );
    }
  }

  Future<RevenueFilters?> _showFilters(
    BuildContext context,
    RevenueFilters initial,
  ) async {
    var draft = initial;
    return showGeneralDialog<RevenueFilters>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filters',
      pageBuilder: (ctx, a1, a2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Theme.of(ctx).colorScheme.surface,
            child: SizedBox(
              width: 360,
              height: MediaQuery.sizeOf(ctx).height,
              child: StatefulBuilder(
                builder: (ctx, setLocal) {
                  return SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Filters',
                                  style: Theme.of(ctx).textTheme.titleLarge,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              DropdownButtonFormField<RevenueStreamKind?>(
                                // ignore: deprecated_member_use
                                value: draft.stream,
                                decoration: const InputDecoration(
                                  labelText: 'Stream',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Any'),
                                  ),
                                  for (final s in RevenueStreamKind.values)
                                    DropdownMenuItem(
                                      value: s,
                                      child: Text(s.label),
                                    ),
                                ],
                                onChanged: (v) => setLocal(() {
                                  draft = v == null
                                      ? draft.copyWith(clearStream: true)
                                      : draft.copyWith(stream: v);
                                }),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<RevenueTxnStatus?>(
                                // ignore: deprecated_member_use
                                value: draft.status,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Any'),
                                  ),
                                  for (final s in RevenueTxnStatus.values)
                                    DropdownMenuItem(
                                      value: s,
                                      child: Text(s.label),
                                    ),
                                ],
                                onChanged: (v) => setLocal(() {
                                  draft = v == null
                                      ? draft.copyWith(clearStatus: true)
                                      : draft.copyWith(status: v);
                                }),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: CfButton(
                                  label: 'Reset',
                                  variant: CfButtonVariant.secondary,
                                  onPressed: () =>
                                      Navigator.pop(ctx, RevenueFilters.empty),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CfButton(
                                  label: 'Apply',
                                  onPressed: () => Navigator.pop(ctx, draft),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary, required this.money});

  final RevenueSummary summary;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final cards = [
      CfStatTile(
        icon: Icons.payments_outlined,
        title: 'Est. total',
        value: money.format(summary.estimatedTotal),
        compact: true,
      ),
      CfStatTile(
        icon: Icons.campaign_outlined,
        title: 'Ads est.',
        value: money.format(summary.adsEstimated),
        compact: true,
      ),
      CfStatTile(
        icon: Icons.handshake_outlined,
        title: 'Sponsorship est.',
        value: money.format(summary.sponsorshipEstimated),
        compact: true,
      ),
      CfStatTile(
        icon: Icons.subscriptions_outlined,
        title: 'Subscriptions',
        value: money.format(summary.subscriptionEstimated),
        compact: true,
      ),
      CfStatTile(
        icon: Icons.receipt_long_outlined,
        title: 'Entries',
        value: '${summary.transactionCount}',
        compact: true,
      ),
      CfStatTile(
        icon: Icons.ads_click_outlined,
        title: 'Ad campaigns',
        value: '${summary.activeCampaigns}',
        compact: true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 3
            : c.maxWidth >= 700
                ? 2
                : 1;
        const spacing = 12.0;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: w, child: card),
          ],
        );
      },
    );
  }
}

class _EntriesTable extends StatelessWidget {
  const _EntriesTable({
    required this.title,
    required this.entries,
    required this.money,
  });

  final String title;
  final List<ManagedRevenueEntry> entries;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return CfCard(
        child: CfEmptyState(
          icon: Icons.payments_outlined,
          title: 'No revenue entries',
          message:
              'Estimates appear when ads/sponsored campaigns have estimatedRevenue, '
              'or when rows exist in admin_revenue_ledger.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        CfCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Stream')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Source')),
              ],
              rows: [
                for (final e in entries)
                  DataRow(
                    cells: [
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            e.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(e.stream.label)),
                      DataCell(Text(money.format(e.amount))),
                      DataCell(
                        CfStatusBadge(
                          label: e.status.label,
                          tone: e.status == RevenueTxnStatus.estimated
                              ? CfBadgeTone.warning
                              : CfBadgeTone.info,
                          compact: true,
                        ),
                      ),
                      DataCell(Text(e.sourceId ?? '—')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_card.dart';
import '../../../shared/widgets/cf_dialog.dart';
import '../../../shared/widgets/cf_empty_state.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../../shared/widgets/cf_page.dart';
import '../../../shared/widgets/cf_search_bar.dart';
import '../../../shared/widgets/cf_snackbar.dart';
import '../../../shared/widgets/cf_stat_tile.dart';
import '../../../shared/widgets/cf_status_badge.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/managed_series.dart';
import '../providers/series_admin_providers.dart';

final _dateFmt = DateFormat('d MMM yyyy');
final _dateTimeFmt = DateFormat('d MMM yyyy, HH:mm');

CfBadgeTone _statusTone(String status) => switch (status) {
  'active' || 'approved' => CfBadgeTone.success,
  'pending' || 'draft' || 'pendingApproval' => CfBadgeTone.warning,
  'suspended' || 'rejected' => CfBadgeTone.danger,
  _ => CfBadgeTone.neutral,
};

IconData _familyIcon(OrgFamily f) => switch (f) {
  OrgFamily.associations => Icons.account_balance_outlined,
  OrgFamily.clubs => Icons.shield_outlined,
  OrgFamily.series => Icons.emoji_events_outlined,
};

/// Platform oversight of mobile Orgs: Associations, Clubs and Series.
///
/// Read + moderate only (suspend / restore / archive). Org owners and admins
/// run their orgs in the CrickFlow mobile app.
class OrgsSeriesScreen extends ConsumerStatefulWidget {
  const OrgsSeriesScreen({super.key});

  @override
  ConsumerState<OrgsSeriesScreen> createState() => _OrgsSeriesScreenState();
}

class _OrgsSeriesScreenState extends ConsumerState<OrgsSeriesScreen> {
  final _search = TextEditingController();
  OrgFamily? _family;
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = [
        'Content',
        'Orgs & Series',
      ];
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(managedSeriesListProvider);
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 600 ? 12.0 : 20.0;
    return PermissionGate(
      permission: AdminPermission.canManageOrganizations,
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(managedSeriesListProvider),
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 32),
          children: [
            CfPageHeader(
              title: 'Orgs & Series',
              subtitle:
                  'Oversight of associations, clubs and series created in the '
                  'CrickFlow app. Owners manage their orgs in the app; staff '
                  'can review them and suspend, restore or archive.',
              actions: [
                CfButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  variant: CfButtonVariant.ghost,
                  onPressed: () => ref.invalidate(managedSeriesListProvider),
                ),
              ],
            ),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: CfLoadingState(message: 'Loading orgs…'),
              ),
              error: (e, _) => CfErrorState(
                title: 'Could not load orgs',
                message: '$e',
                onRetry: () => ref.invalidate(managedSeriesListProvider),
              ),
              data: (all) {
                final visible = filterOrgs(
                  all,
                  family: _family,
                  status: _status,
                  query: _search.text,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Summary(all: all),
                    const SizedBox(height: 16),
                    _toolbar(),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: CfEmptyState(
                          icon: Icons.groups_2_outlined,
                          title: 'No orgs match',
                          message: 'Change the filters or search.',
                        ),
                      )
                    else
                      for (final s in visible)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OrgRow(series: s),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: CfSearchBar(
            controller: _search,
            hintText: 'Search name, ID, owner UID, region…',
            onChanged: (_) => setState(() {}),
            onClear: () => setState(_search.clear),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _family == null,
              onSelected: (_) => setState(() => _family = null),
            ),
            for (final f in OrgFamily.values)
              ChoiceChip(
                label: Text(f.label),
                selected: _family == f,
                onSelected: (_) => setState(() => _family = f),
              ),
          ],
        ),
        DropdownButton<String>(
          value: _status,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: '', child: Text('Any status')),
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'draft', child: Text('Draft')),
            DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
            DropdownMenuItem(value: 'archived', child: Text('Archived')),
          ],
          onChanged: (v) => setState(() => _status = v ?? ''),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.all});

  final List<ManagedSeries> all;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    int count(OrgFamily f) => all.where((s) => s.family == f).length;
    final tiles = [
      CfStatTile(
        icon: Icons.hub_outlined,
        title: 'All orgs',
        value: '${all.length}',
        compact: true,
      ),
      CfStatTile(
        icon: _familyIcon(OrgFamily.associations),
        title: 'Associations',
        value: '${count(OrgFamily.associations)}',
        accentColor: colors.info,
        compact: true,
      ),
      CfStatTile(
        icon: _familyIcon(OrgFamily.clubs),
        title: 'Clubs',
        value: '${count(OrgFamily.clubs)}',
        accentColor: colors.success,
        compact: true,
      ),
      CfStatTile(
        icon: _familyIcon(OrgFamily.series),
        title: 'Series',
        value: '${count(OrgFamily.series)}',
        compact: true,
      ),
      CfStatTile(
        icon: Icons.block_outlined,
        title: 'Suspended / archived',
        value: '${all.where((s) => s.isSuspended || s.isArchived).length}',
        accentColor: colors.warning,
        compact: true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 5
            : c.maxWidth >= 760
            ? 3
            : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _OrgRow extends StatelessWidget {
  const _OrgRow({required this.series});

  final ManagedSeries series;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final s = series;
    final created = s.createdAt == null
        ? ''
        : ' · created ${_dateFmt.format(s.createdAt!.toLocal())}';
    return CfCard(
      onTap: () => showOrgDetailDialog(context, s),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.info.withValues(alpha: 0.12),
            child: Icon(_familyIcon(s.family), color: colors.info),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CfStatusBadge(label: s.kindLabel, compact: true),
                    CfStatusBadge(
                      label: s.status,
                      compact: true,
                      tone: _statusTone(s.status),
                    ),
                    Text(
                      '${s.clubCount} clubs · ${s.playerCount} players$created',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// Opens the org investigation dialog (overview, admins, clubs, approvals,
/// audit) with moderation actions for staff with `canManageOrganizations`.
Future<void> showOrgDetailDialog(BuildContext context, ManagedSeries series) {
  return showDialog<void>(
    context: context,
    builder: (_) => _OrgDetailDialog(seriesId: series.id, title: series.name),
  );
}

class _OrgDetailDialog extends ConsumerStatefulWidget {
  const _OrgDetailDialog({required this.seriesId, required this.title});

  final String seriesId;
  final String title;

  @override
  ConsumerState<_OrgDetailDialog> createState() => _OrgDetailDialogState();
}

class _OrgDetailDialogState extends ConsumerState<_OrgDetailDialog> {
  bool _busy = false;

  Future<String?> _askReason(String title, String message, bool danger) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reason (shown in the org audit log)',
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
    final text = ctrl.text.trim();
    ctrl.dispose();
    return ok == true ? text : null;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(seriesInvestigationProvider(widget.seriesId));
      ref.invalidate(managedSeriesListProvider);
      if (mounted) CfSnack.success(context, done);
    } catch (e) {
      if (mounted) {
        CfSnack.error(
          context,
          '$e'.contains('permission-denied')
              ? 'Firestore denied the change. Your role needs the '
                    '"Moderate orgs & series" permission.'
              : 'Could not update: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeSeries(ManagedSeries s, String next) async {
    final label = OrgModeration.actionLabel(next);
    final reason = await _askReason('$label ${s.name}?', switch (next) {
      'suspended' =>
        'The org is suspended: its admins cannot manage it until a staff '
            'member restores it.',
      'archived' =>
        'The org becomes read-only history. It can be restored later.',
      _ => 'The org becomes active again for its owner and members.',
    }, next != 'active');
    if (reason == null) return;
    final actor = ref.read(adminSessionProvider).adminUser;
    if (actor == null) return;
    await _run(
      () => ref
          .read(seriesAdminRepositoryProvider)
          .setSeriesStatus(s, nextStatus: next, actor: actor, reason: reason),
      '${s.name}: ${next == 'active' ? 'restored' : next}',
    );
  }

  Future<void> _changeClub(String seriesId, SeriesRow club, String next) async {
    final name = club.str('name', club.id);
    final reason = await _askReason(
      '${next == 'suspended' ? 'Suspend' : 'Restore'} club $name?',
      next == 'suspended'
          ? 'The club is suspended inside this org.'
          : 'The club becomes approved again.',
      next == 'suspended',
    );
    if (reason == null) return;
    final actor = ref.read(adminSessionProvider).adminUser;
    if (actor == null) return;
    await _run(
      () => ref
          .read(seriesAdminRepositoryProvider)
          .setClubStatus(
            seriesId,
            club,
            nextStatus: next,
            actor: actor,
            reason: reason,
          ),
      'Club $name: ${next == 'approved' ? 'restored' : next}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(seriesInvestigationProvider(widget.seriesId));
    final canModerate = ref
        .watch(permissionCheckerProvider)
        .can(AdminPermission.canManageOrganizations);
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: size.height * 0.88,
        ),
        child: DefaultTabController(
          length: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: detail.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48),
                    child: CfLoadingState(message: 'Loading org…'),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: CfErrorState(
                      title: 'Could not load this org',
                      message: '$e',
                    ),
                  ),
                  data: (inv) => inv == null
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CfEmptyState(
                            icon: Icons.search_off,
                            title: 'Org not found',
                            message: 'It may have been removed.',
                          ),
                        )
                      : _tabs(context, inv, canModerate),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs(
    BuildContext context,
    SeriesInvestigation inv,
    bool canModerate,
  ) {
    String when(SeriesRow r, String key) {
      final d = r.date(key);
      return d == null ? '' : _dateTimeFmt.format(d.toLocal());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'Overview'),
            Tab(text: 'Admins (${inv.admins.length})'),
            Tab(text: 'Clubs (${inv.clubs.length})'),
            Tab(text: 'Approvals (${inv.pendingApprovals} pending)'),
            Tab(text: 'Audit (${inv.auditLogs.length})'),
          ],
        ),
        Flexible(
          child: TabBarView(
            children: [
              _overview(context, inv, canModerate),
              _list(
                inv.admins,
                empty: 'No admins besides the owner.',
                build: (r) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: SelectableText(r.str('userId', r.id)),
                  subtitle: Text(
                    'Role: ${r.str('role', 'admin')} · added by '
                    '${r.str('addedBy', '—')}',
                  ),
                  trailing: CfStatusBadge(
                    label: r.str('status', 'active'),
                    compact: true,
                    tone: _statusTone(r.str('status', 'active')),
                  ),
                ),
              ),
              _list(
                inv.clubs,
                empty: 'No clubs in this org yet.',
                build: (r) {
                  final status = r.str('status', 'pending');
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(r.str('name', r.id)),
                    subtitle: Text('Created by ${r.str('createdBy', '—')}'),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CfStatusBadge(
                          label: status,
                          compact: true,
                          tone: _statusTone(status),
                        ),
                        if (canModerate && status == 'approved')
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _changeClub(
                                    inv.series.id,
                                    r,
                                    'suspended',
                                  ),
                            child: const Text('Suspend'),
                          ),
                        if (canModerate && status == 'suspended')
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () =>
                                      _changeClub(inv.series.id, r, 'approved'),
                            child: const Text('Restore'),
                          ),
                      ],
                    ),
                  );
                },
              ),
              _list(
                inv.approvals,
                empty: 'No approval requests.',
                build: (r) {
                  final at = when(r, 'createdAt');
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.fact_check_outlined),
                    title: Text(r.str('type', r.str('targetType', 'request'))),
                    subtitle: Text(
                      'Requested by ${r.str('requestedBy', '—')}'
                      '${at.isEmpty ? '' : ' · $at'}',
                    ),
                    trailing: CfStatusBadge(
                      label: r.str('status', 'pending'),
                      compact: true,
                      tone: _statusTone(r.str('status', 'pending')),
                    ),
                  );
                },
              ),
              _list(
                inv.auditLogs,
                empty: 'No audit activity yet.',
                build: (r) {
                  final reason = r.str('reason');
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(r.str('action', 'event')),
                    subtitle: Text(
                      '${r.str('actorRole')} ${r.str('actorUserId')}'
                      '${reason.isEmpty ? '' : ' · $reason'}',
                    ),
                    trailing: Text(
                      when(r, 'timestamp'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overview(
    BuildContext context,
    SeriesInvestigation inv,
    bool canModerate,
  ) {
    final s = inv.series;
    final colors = context.adminColors;
    final place = [s.region, s.country].where((e) => e.isNotEmpty).join(', ');
    Widget row(String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: TextStyle(color: colors.textMuted)),
          ),
          Expanded(child: v),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CfStatusBadge(label: s.kindLabel),
            CfStatusBadge(label: s.status, tone: _statusTone(s.status)),
            CfStatusBadge(label: s.family.label, tone: CfBadgeTone.info),
          ],
        ),
        const SizedBox(height: 12),
        row(
          'Org ID',
          Row(
            children: [
              Flexible(child: SelectableText(s.id)),
              IconButton(
                tooltip: 'Copy ID',
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: s.id));
                  if (context.mounted) CfSnack.info(context, 'Org ID copied');
                },
              ),
            ],
          ),
        ),
        row('Owner UID', SelectableText(s.ownerUid.isEmpty ? '—' : s.ownerUid)),
        row('Location', Text(place.isEmpty ? '—' : place)),
        row(
          'Created',
          Text(
            s.createdAt == null
                ? '—'
                : _dateTimeFmt.format(s.createdAt!.toLocal()),
          ),
        ),
        row('Members', Text('${s.clubCount} clubs · ${s.playerCount} players')),
        if (s.description.isNotEmpty) row('Description', Text(s.description)),
        const SizedBox(height: 16),
        if (canModerate)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final next in OrgModeration.nextSeriesStatuses(s.status))
                CfButton(
                  label: OrgModeration.actionLabel(next),
                  icon: switch (next) {
                    'active' => Icons.restore,
                    'suspended' => Icons.block,
                    _ => Icons.archive_outlined,
                  },
                  variant: next == 'active'
                      ? CfButtonVariant.primary
                      : next == 'suspended'
                      ? CfButtonVariant.danger
                      : CfButtonVariant.outlined,
                  onPressed: _busy ? null : () => _changeSeries(s, next),
                ),
            ],
          )
        else
          Text(
            'Read-only: your role cannot moderate orgs.',
            style: TextStyle(color: colors.textMuted),
          ),
        const SizedBox(height: 8),
        Text(
          'Ownership, admins, clubs and announcements are managed by the org '
          'owner in the CrickFlow app.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _list(
    List<SeriesRow> rows, {
    required String empty,
    required Widget Function(SeriesRow) build,
  }) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Text(empty)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => build(rows[i]),
    );
  }
}

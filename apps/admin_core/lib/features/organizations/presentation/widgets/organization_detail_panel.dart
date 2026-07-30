import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../models/admin_permission.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../models/managed_organization.dart';
import '../../providers/organizations_providers.dart';
import 'organization_status_badge.dart';

class OrganizationDetailPanel extends ConsumerStatefulWidget {
  const OrganizationDetailPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<OrganizationDetailPanel> createState() =>
      _OrganizationDetailPanelState();
}

class _OrganizationDetailPanelState
    extends ConsumerState<OrganizationDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late List<OrgDetailTab> _tabList;

  @override
  void initState() {
    super.initState();
    _tabList = OrgDetailTab.values;
    _tabs = TabController(length: _tabList.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(selectedManagedOrganizationProvider);
    final colors = context.adminColors;
    final canManage = ref
        .watch(permissionCheckerProvider)
        .can(AdminPermission.canManageOrganizations);

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SizedBox(
        width: 520,
        child: async.when(
          loading: () =>
              const CfLoadingState(message: 'Loading organization…'),
          error: (e, _) => Center(child: Text('$e')),
          data: (org) {
            if (org == null) {
              return const CfEmptyState(
                icon: Icons.apartment_outlined,
                title: 'No organization selected',
                message: 'Select a row to view details',
              );
            }
            return Column(
              children: [
                // Header
                _PanelHeader(org: org, onClose: widget.onClose),
                // Tab bar
                TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final t in _tabList) Tab(text: t.label),
                  ],
                ),
                // Tab views
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _OverviewTab(org: org, canManage: canManage),
                      _AdministratorsTab(org: org, canManage: canManage),
                      _PlaceholderTab(
                        icon: Icons.groups_2_outlined,
                        label: 'Teams',
                        subtitle:
                            'All teams belonging to this organization appear here.',
                      ),
                      _PlaceholderTab(
                        icon: Icons.sports_cricket_outlined,
                        label: 'Players',
                        subtitle: 'Players associated with this organization.',
                      ),
                      _PlaceholderTab(
                        icon: Icons.emoji_events_outlined,
                        label: 'Tournaments',
                        subtitle: 'Tournaments created by this organization.',
                      ),
                      _PlaceholderTab(
                        icon: Icons.sports_outlined,
                        label: 'Grounds',
                        subtitle: 'Grounds managed by this organization.',
                      ),
                      _PlaceholderTab(
                        icon: Icons.scoreboard_outlined,
                        label: 'Matches',
                        subtitle:
                            'Upcoming, live, completed and cancelled matches.',
                      ),
                      _PlaceholderTab(
                        icon: Icons.stream_outlined,
                        label: 'Broadcasts',
                        subtitle: 'Live and completed streams by this org.',
                      ),
                      _PlaceholderTab(
                        icon: Icons.forum_outlined,
                        label: 'Community',
                        subtitle:
                            'Community posts, discover posts, announcements, followers.',
                      ),
                      _AnalyticsTab(org: org),
                      _DocumentsTab(),
                      _PlaceholderTab(
                        icon: Icons.assessment_outlined,
                        label: 'Reports',
                        subtitle: 'Reports related to this organization.',
                      ),
                      _AuditTab(orgId: org.id),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Panel header ─────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.org, required this.onClose});

  final ManagedOrganization org;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Column(
      children: [
        // Close bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Organization Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
            ],
          ),
        ),
        // Hero section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              // Banner
              if (org.bannerUrl != null && org.bannerUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    org.bannerUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (org.bannerUrl != null && org.bannerUrl!.isNotEmpty)
                const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colors.background,
                    child: org.logoUrl == null || org.logoUrl!.isEmpty
                        ? Icon(
                            Icons.apartment,
                            size: 26,
                            color: colors.textMuted,
                          )
                        : ClipOval(
                            child: Image.network(
                              org.logoUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.apartment,
                                size: 26,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name.isEmpty ? '—' : org.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (org.locationLabel != '—')
                          Text(
                            org.locationLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OrganizationStatusBadge(status: org.displayStatus),
                  OrganizationTypeBadge(type: org.type, compact: true),
                  if (org.featured) const OrganizationFeaturedBadge(),
                  if (org.isVerified)
                    const _Pill(
                      label: 'Verified',
                      color: AdminColors.primaryBlue,
                      icon: Icons.verified,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Overview tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.org, required this.canManage});

  final ManagedOrganization org;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller =
        ref.read(organizationsListControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _InfoSection(org: org),
        const SizedBox(height: 16),
        _RelatedCounts(orgId: org.id),
        if (canManage) ...[
          const SizedBox(height: 16),
          _ActionsSection(org: org, controller: controller),
        ],
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.org});

  final ManagedOrganization org;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    final rows = <(String, String)>[
      ('ID', org.id),
      ('Slug', org.slug.isEmpty ? '—' : org.slug),
      ('Type', org.type.label),
      if (org.registrationNumber.isNotEmpty)
        ('Reg. No.', org.registrationNumber),
      if (org.establishedYear != null)
        ('Est. Year', '${org.establishedYear}'),
      if (org.email.isNotEmpty) ('Email', org.email),
      if (org.phone.isNotEmpty) ('Phone', org.phone),
      if (org.website.isNotEmpty) ('Website', org.website),
      ('Location', org.locationLabel),
      if (org.address.isNotEmpty) ('Address', org.address),
      if (org.description.isNotEmpty) ('Description', org.description),
      (
        'Created',
        org.createdAt == null ? '—' : df.format(org.createdAt!),
      ),
      if (org.approvedAt != null)
        ('Approved', df.format(org.approvedAt!)),
      if (org.verifiedAt != null)
        ('Verified', df.format(org.verifiedAt!)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Organization Info'),
        const SizedBox(height: 8),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    row.$1,
                    style: TextStyle(
                      color: context.adminColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Related counts ───────────────────────────────────────────────────────────

class _RelatedCounts extends ConsumerWidget {
  const _RelatedCounts({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organizationRelatedCountsProvider(orgId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Related Resources'),
        const SizedBox(height: 8),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Text('$e'),
          data: (c) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(
                label: 'Users',
                value: c.users,
                icon: Icons.people_outline,
              ),
              _CountChip(
                label: 'Teams',
                value: c.teams,
                icon: Icons.groups_outlined,
              ),
              _CountChip(
                label: 'Tournaments',
                value: c.tournaments,
                icon: Icons.emoji_events_outlined,
              ),
              _CountChip(
                label: 'Matches',
                value: c.matches,
                icon: Icons.scoreboard_outlined,
              ),
              _CountChip(
                label: 'Grounds',
                value: c.grounds,
                icon: Icons.sports_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: colors.textMuted),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Actions ──────────────────────────────────────────────────────────────────

class _ActionsSection extends ConsumerWidget {
  const _ActionsSection({
    required this.org,
    required this.controller,
  });

  final ManagedOrganization org;
  final OrganizationsListController controller;

  Future<String?> _askReason(BuildContext context, String title) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
          autofocus: true,
        ),
        actions: [
          CfButton(
            label: 'Cancel',
            variant: CfButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
          ),
          CfButton(
            label: 'Confirm',
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Edit
            CfButton(
              label: 'Edit',
              icon: Icons.edit_outlined,
              variant: CfButtonVariant.secondary,
              onPressed: () => controller.openEditComposer(org.id),
            ),
            // Approve (pending → active)
            if (org.status == ManagedOrganizationStatus.pending)
              CfButton(
                label: 'Approve',
                icon: Icons.check_circle_outline,
                onPressed: () async {
                  final r = await _askReason(context, 'Approve organization');
                  if (r == null) return;
                  await controller.setStatus(
                    org,
                    ManagedOrganizationStatus.active,
                    reason: r.isEmpty ? null : r,
                  );
                },
              ),
            // Verify
            if (!org.isVerified && !org.isSoftDeleted)
              CfButton(
                label: 'Verify',
                icon: Icons.verified_outlined,
                onPressed: () async {
                  final r = await _askReason(context, 'Verify organization');
                  if (r == null) return;
                  await controller.setStatus(
                    org,
                    ManagedOrganizationStatus.verified,
                    reason: r.isEmpty ? null : r,
                  );
                },
              ),
            // Activate
            if (!org.isSoftDeleted &&
                org.status != ManagedOrganizationStatus.active &&
                org.status != ManagedOrganizationStatus.pending)
              CfButton(
                label: 'Activate',
                icon: Icons.play_circle_outline,
                onPressed: () async {
                  final r = await _askReason(context, 'Activate organization');
                  if (r == null) return;
                  await controller.setStatus(
                    org,
                    ManagedOrganizationStatus.active,
                    reason: r.isEmpty ? null : r,
                  );
                },
              ),
            // Deactivate
            if (!org.isSoftDeleted &&
                org.status != ManagedOrganizationStatus.inactive)
              CfButton(
                label: 'Deactivate',
                icon: Icons.pause_circle_outline,
                variant: CfButtonVariant.secondary,
                onPressed: () async {
                  final r =
                      await _askReason(context, 'Deactivate organization');
                  if (r == null) return;
                  await controller.setStatus(
                    org,
                    ManagedOrganizationStatus.inactive,
                    reason: r.isEmpty ? null : r,
                  );
                },
              ),
            // Suspend
            if (!org.isSoftDeleted &&
                org.status != ManagedOrganizationStatus.suspended)
              CfButton(
                label: 'Suspend',
                icon: Icons.block_outlined,
                variant: CfButtonVariant.danger,
                onPressed: () async {
                  final r = await _askReason(context, 'Suspend organization');
                  if (r == null) return;
                  await controller.setStatus(
                    org,
                    ManagedOrganizationStatus.suspended,
                    reason: r.isEmpty ? null : r,
                  );
                },
              ),
            // Feature / Unfeature
            CfButton(
              label: org.featured ? 'Remove Feature' : 'Feature',
              icon: org.featured
                  ? Icons.star_border_outlined
                  : Icons.star_outline,
              variant: CfButtonVariant.secondary,
              onPressed: () async {
                await controller.setFeatured(
                  org,
                  featured: !org.featured,
                );
              },
            ),
            // Archive / Unarchive
            if (!org.isSoftDeleted)
              CfButton(
                label: org.isArchived ? 'Unarchive' : 'Archive',
                icon: org.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                variant: CfButtonVariant.secondary,
                onPressed: () async {
                  final r = await _askReason(
                    context,
                    org.isArchived ? 'Unarchive' : 'Archive organization',
                  );
                  if (r == null) return;
                  if (org.isArchived) {
                    await controller.unarchive(
                      org,
                      reason: r.isEmpty ? null : r,
                    );
                  } else {
                    await controller.archive(
                      org,
                      reason: r.isEmpty ? null : r,
                    );
                  }
                },
              ),
            // Delete / Restore
            if (!org.isSoftDeleted)
              CfButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                variant: CfButtonVariant.danger,
                onPressed: () async {
                  final r =
                      await _askReason(context, 'Soft-delete organization');
                  if (r == null) return;
                  await controller.softDelete(
                    org,
                    reason: r.isEmpty ? null : r,
                  );
                },
              )
            else
              CfButton(
                label: 'Restore',
                icon: Icons.restore_outlined,
                onPressed: () async {
                  final r = await _askReason(context, 'Restore organization');
                  if (r == null) return;
                  await controller.restore(
                    org,
                    reason: r.isEmpty ? null : r,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Administrators tab ───────────────────────────────────────────────────────

class _AdministratorsTab extends ConsumerStatefulWidget {
  const _AdministratorsTab({required this.org, required this.canManage});

  final ManagedOrganization org;
  final bool canManage;

  @override
  ConsumerState<_AdministratorsTab> createState() => _AdministratorsTabState();
}

class _AdministratorsTabState extends ConsumerState<_AdministratorsTab> {
  final _linkController = TextEditingController();
  final _transferController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _linkController.dispose();
    _transferController.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final key = _linkController.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(organizationsListControllerProvider.notifier)
          .linkOrgAdmin(widget.org, key);
      _linkController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Org Admin linked')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Org Admin'),
        content: Text(
          'Remove organization scope from '
          '${widget.org.primaryAdminEmail ?? widget.org.primaryAdminUid}? '
          'The Auth user is kept.',
        ),
        actions: [
          CfButton(
            label: 'Cancel',
            variant: CfButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CfButton(
            label: 'Unlink',
            variant: CfButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(organizationsListControllerProvider.notifier)
          .unlinkOrgAdmin(widget.org);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Org Admin unlinked')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transfer() async {
    final key = _transferController.text.trim();
    if (key.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer Ownership'),
        content:
            Text('Transfer ownership to "$key"? Current admin will be replaced.'),
        actions: [
          CfButton(
            label: 'Cancel',
            variant: CfButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CfButton(
            label: 'Transfer',
            variant: CfButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(organizationsListControllerProvider.notifier)
          .transferOwnership(widget.org, key);
      _transferController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ownership transferred')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final org = widget.org;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _SectionTitle('Primary Administrator'),
        const SizedBox(height: 8),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ),
        ],
        if (org.hasPrimaryAdmin) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AdminColors.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.person_outline,
                    color: AdminColors.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.primaryAdminEmail?.isNotEmpty == true
                            ? org.primaryAdminEmail!
                            : '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'UID: ${org.primaryAdminUid ?? '—'}',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AdminColors.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Org Admin',
                          style: TextStyle(
                            color: AdminColors.primaryBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.canManage) ...[
            CfButton(
              label: _busy ? 'Working…' : 'Unlink Admin',
              variant: CfButtonVariant.danger,
              icon: Icons.link_off,
              onPressed: _busy ? null : _unlink,
            ),
            const SizedBox(height: 20),
            _SectionTitle('Transfer Ownership'),
            const SizedBox(height: 8),
            Text(
              'Transfer ownership to a different admin user.',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _transferController,
              decoration: const InputDecoration(
                labelText: 'New Owner UID or email',
                hintText: 'uid or admin@example.com',
                prefixIcon: Icon(Icons.swap_horiz_outlined),
              ),
            ),
            const SizedBox(height: 8),
            CfButton(
              label: _busy ? 'Transferring…' : 'Transfer Ownership',
              icon: Icons.swap_horiz,
              variant: CfButtonVariant.secondary,
              onPressed: _busy ? null : _transfer,
            ),
          ],
        ] else if (widget.canManage) ...[
          Text(
            'No admin linked to this organization. Link an existing admin_users profile (Auth UID or email).',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _linkController,
            decoration: const InputDecoration(
              labelText: 'Admin UID or email',
              hintText: 'uid or admin@example.com',
              prefixIcon: Icon(Icons.person_add_outlined),
            ),
          ),
          const SizedBox(height: 8),
          CfButton(
            label: _busy ? 'Linking…' : 'Link Org Admin',
            icon: Icons.link,
            onPressed: _busy ? null : _link,
          ),
        ] else
          Text(
            'No administrator linked to this organization.',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
      ],
    );
  }
}

// ─── Analytics tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab({required this.org});

  final ManagedOrganization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organizationRelatedCountsProvider(org.id));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _SectionTitle('Organization Analytics'),
        const SizedBox(height: 8),
        async.when(
          loading: () => const CfLoadingState(message: 'Loading analytics…'),
          error: (e, _) => Text('$e'),
          data: (c) => Column(
            children: [
              _AnalyticsCard(
                title: 'Users',
                value: c.users,
                icon: Icons.people_outline,
                color: AdminColors.primaryBlue,
              ),
              _AnalyticsCard(
                title: 'Teams',
                value: c.teams,
                icon: Icons.groups_outlined,
                color: const Color(0xFF00897B),
              ),
              _AnalyticsCard(
                title: 'Tournaments',
                value: c.tournaments,
                icon: Icons.emoji_events_outlined,
                color: const Color(0xFFE65100),
              ),
              _AnalyticsCard(
                title: 'Matches',
                value: c.matches,
                icon: Icons.scoreboard_outlined,
                color: const Color(0xFF6A1B9A),
              ),
              _AnalyticsCard(
                title: 'Grounds',
                value: c.grounds,
                icon: Icons.sports_outlined,
                color: const Color(0xFF2E7D32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.adminColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.adminColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Advanced Analytics',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Growth, engagement, streaming, and revenue analytics will appear here once connected to the Analytics module.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.adminColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Documents tab ────────────────────────────────────────────────────────────

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab();

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final docs = [
      ('Organization Certificate', Icons.description_outlined),
      ('Registration Documents', Icons.article_outlined),
      ('Tax Documents', Icons.receipt_long_outlined),
      ('Identity Verification', Icons.verified_user_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _SectionTitle('Documents'),
        const SizedBox(height: 4),
        Text(
          'Document upload will be available in a future update.',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 16),
        for (final doc in docs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(doc.$2, color: colors.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    doc.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    'Not uploaded',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Audit tab ────────────────────────────────────────────────────────────────

class _AuditTab extends ConsumerWidget {
  const _AuditTab({required this.orgId});

  final String orgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organizationAuditProvider(orgId));
    final colors = context.adminColors;
    final df = DateFormat.yMMMd().add_jm();

    return async.when(
      loading: () => const CfLoadingState(message: 'Loading audit log…'),
      error: (e, _) => Center(child: Text('$e')),
      data: (entries) {
        if (entries.isEmpty) {
          return const CfEmptyState(
            icon: Icons.history_outlined,
            title: 'No audit entries',
            message: 'Actions on this organization will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: entries.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: colors.border),
          itemBuilder: (context, i) {
            final e = entries[i];
            return ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _actionColor(e.action, colors)
                    .withValues(alpha: 0.12),
                child: Icon(
                  _actionIcon(e.action),
                  size: 14,
                  color: _actionColor(e.action, colors),
                ),
              ),
              title: Text(
                e.action.replaceAll('.', ' › ').replaceAll('_', ' '),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'by ${e.actorEmail}',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                  Text(
                    df.format(e.timestamp),
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                  if (e.reason?.isNotEmpty == true)
                    Text(
                      'Reason: ${e.reason}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.warning,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _actionColor(String action, adminColors) {
    if (action.contains('deleted') || action.contains('suspended')) {
      return adminColors.error as Color;
    }
    if (action.contains('created') || action.contains('restored')) {
      return adminColors.success as Color;
    }
    return AdminColors.primaryBlue;
  }

  IconData _actionIcon(String action) {
    if (action.contains('created')) return Icons.add_circle_outline;
    if (action.contains('edited')) return Icons.edit_outlined;
    if (action.contains('deleted')) return Icons.delete_outline;
    if (action.contains('restored')) return Icons.restore_outlined;
    if (action.contains('suspended')) return Icons.block_outlined;
    if (action.contains('verified')) return Icons.verified_outlined;
    if (action.contains('approved')) return Icons.check_circle_outline;
    if (action.contains('admin')) return Icons.person_outline;
    if (action.contains('featured')) return Icons.star_outline;
    if (action.contains('archived')) return Icons.archive_outlined;
    return Icons.history_outlined;
  }
}

// ─── Placeholder tab ──────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CfEmptyState(
      icon: icon,
      title: label,
      message: subtitle,
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: context.adminColors.textMuted,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

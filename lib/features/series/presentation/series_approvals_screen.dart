import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';

/// Pending org approvals — admin-only review queue.
class SeriesApprovalsScreen extends ConsumerStatefulWidget {
  const SeriesApprovalsScreen({super.key, required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<SeriesApprovalsScreen> createState() =>
      _SeriesApprovalsScreenState();
}

class _SeriesApprovalsScreenState extends ConsumerState<SeriesApprovalsScreen> {
  SeriesApprovalTargetType? _filter;
  final Set<String> _busyIds = {};

  Future<void> _review(
    SeriesApprovalModel approval,
    SeriesApprovalStatus decision,
  ) async {
    if (_busyIds.contains(approval.id)) return;

    var reason = '';
    if (decision == SeriesApprovalStatus.rejected) {
      final r = await askRejectionReason(context);
      if (r == null) return;
      reason = r;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve request?'),
          content: Text(
            'Approve this ${approval.targetType.label.toLowerCase()}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('approve_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busyIds.add(approval.id));
    try {
      await ref
          .read(seriesApprovalRepositoryProvider)
          .reviewSeriesApproval(
            seriesId: widget.seriesId,
            approvalId: approval.id,
            decision: decision,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == SeriesApprovalStatus.approved
                ? 'Request approved'
                : 'Request rejected',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not review this request')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(approval.id));
    }
  }

  Future<void> _viewIdentity(SeriesApprovalModel approval) async {
    final registrationId =
        approval.metadata['registrationId']?.toString() ??
        (approval.targetType == SeriesApprovalTargetType.playerRegistration
            ? approval.targetId
            : null);
    if (registrationId == null || registrationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registration linked to this request')),
      );
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final result = await ref
          .read(seriesFunctionsServiceProvider)
          .getSeriesRegistrationIdentity(
            seriesId: widget.seriesId,
            registrationId: registrationId,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      final identity = result['identity'];
      final map = identity is Map
          ? Map<String, dynamic>.from(identity)
          : <String, dynamic>{};
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Registration details'),
          content: map.isEmpty
              ? const Text('No private details on file.')
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in map.entries)
                        if ((e.value?.toString().trim() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${seriesIdentityFieldLabel(e.key)}: ${e.value}',
                            ),
                          ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load registration details')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final seriesId = widget.seriesId;
    final role = ref.watch(mySeriesRoleProvider(seriesId));
    if (role != SeriesRole.superAdmin && role != SeriesRole.seriesAdmin) {
      return Scaffold(
        backgroundColor: cf.background,
        appBar: const CfChromeAppBar(title: Text('Approvals')),
        body: const SeriesEmptyState(
          icon: Icons.lock_outline,
          title: 'Admin access required',
          message: 'Only org owners and admins can review pending requests.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: cf.background,
      appBar: const CfChromeAppBar(title: Text('Pending approvals')),
      body: ref
          .watch(pendingSeriesApprovalsProvider(seriesId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => SeriesEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load approvals',
              message: '$e',
            ),
            data: (items) {
              final types = {for (final i in items) i.targetType}.toList()
                ..sort((a, b) => a.label.compareTo(b.label));
              final filtered = _filter == null
                  ? items
                  : items.where((i) => i.targetType == _filter).toList();

              Future<void> refresh() async {
                ref.invalidate(pendingSeriesApprovalsProvider(seriesId));
                await ref.read(pendingSeriesApprovalsProvider(seriesId).future);
              }

              Widget emptyBody({
                required IconData icon,
                required String title,
                required String message,
              }) {
                return RefreshIndicator(
                  onRefresh: refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SeriesEmptyState(
                          icon: icon,
                          title: title,
                          message: message,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  if (types.length > 1)
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceSm,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('All (${items.length})'),
                              selected: _filter == null,
                              onSelected: (_) => setState(() => _filter = null),
                            ),
                          ),
                          for (final t in types)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  '${t.label} (${items.where((i) => i.targetType == t).length})',
                                ),
                                selected: _filter == t,
                                onSelected: (_) => setState(() => _filter = t),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: items.isEmpty
                        ? emptyBody(
                            icon: Icons.task_alt,
                            title: 'All caught up',
                            message: 'There are no pending approvals.',
                          )
                        : filtered.isEmpty
                        ? emptyBody(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'No requests in this filter',
                            message: 'Try another type.',
                          )
                        : RefreshIndicator(
                            onRefresh: refresh,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                AppDimens.spaceMd,
                                AppDimens.spaceSm,
                                AppDimens.spaceMd,
                                AppDimens.spaceXl,
                              ),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppDimens.spaceSm),
                              itemBuilder: (_, i) {
                                final item = filtered[i];
                                return _ApprovalCard(
                                  item: item,
                                  role: role,
                                  busy: _busyIds.contains(item.id),
                                  onApprove: () => _review(
                                    item,
                                    SeriesApprovalStatus.approved,
                                  ),
                                  onReject: () => _review(
                                    item,
                                    SeriesApprovalStatus.rejected,
                                  ),
                                  onViewDetails: () => _viewIdentity(item),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _ApprovalCard extends ConsumerWidget {
  const _ApprovalCard({
    required this.item,
    required this.role,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetails,
  });

  final SeriesApprovalModel item;
  final SeriesRole role;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewDetails;

  bool get _canApprove {
    if (item.targetType != SeriesApprovalTargetType.playerJoin) return true;
    final clubReview = item.metadata['clubReviewStatus']?.toString();
    if (clubReview == 'approved') return true;
    return role == SeriesRole.superAdmin;
  }

  bool get _hasRegistration =>
      item.metadata['registrationId'] != null ||
      item.targetType == SeriesApprovalTargetType.playerRegistration;

  String get _subtitleExtras {
    final meta = item.metadata;
    final parts = <String>[];
    final a = meta['clubAName']?.toString().trim() ?? '';
    final b = meta['clubBName']?.toString().trim() ?? '';
    if (a.isNotEmpty && b.isNotEmpty) {
      parts.add('$a vs $b');
    } else {
      final club = meta['clubName']?.toString().trim() ?? '';
      if (club.isNotEmpty &&
          item.targetType != SeriesApprovalTargetType.clubRegistration) {
        parts.add(club);
      }
    }
    final date = seriesShortDate(item.requestedAt);
    if (date.isNotEmpty) parts.add(date);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final extras = _subtitleExtras;
    final canApprove = _canApprove;
    final clubReviewRaw = item.metadata['clubReviewStatus']?.toString();

    return Material(
      color: cf.card,
      elevation: cf.isLight ? 1 : 0,
      shadowColor: cf.cardShadow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cf.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.targetType.label,
                    style: TextStyle(
                      color: cf.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            _ApprovalSubjectTitle(
              item: item,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cf.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: cf.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: SeriesUserName(
                    item.requestedBy,
                    fallback: 'Member',
                    style: TextStyle(color: cf.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (extras.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                extras,
                style: TextStyle(color: cf.textSecondary, fontSize: 13),
              ),
            ],
            if (clubReviewRaw != null && clubReviewRaw.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                seriesClubReviewLabel(clubReviewRaw),
                style: TextStyle(
                  color: clubReviewRaw == 'approved' ? cf.success : cf.accent,
                  fontSize: 13,
                ),
              ),
            ],
            if (!canApprove) ...[
              const SizedBox(height: 4),
              Text(
                'Waiting for team admin clearance',
                style: TextStyle(fontSize: 12, color: cf.textSecondary),
              ),
            ],
            if (_hasRegistration) ...[
              const SizedBox(height: AppDimens.spaceSm),
              TextButton.icon(
                onPressed: busy ? null : onViewDetails,
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('View details'),
              ),
            ],
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: FilledButton(
                    onPressed: busy || !canApprove ? null : onApprove,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalSubjectTitle extends ConsumerWidget {
  const _ApprovalSubjectTitle({required this.item, this.style});

  final SeriesApprovalModel item;
  final TextStyle? style;

  String get _fallback {
    final meta = item.metadata;
    for (final key in [
      'displayName',
      'clubName',
      'name',
      'title',
      'clubAName',
    ]) {
      final t = meta[key]?.toString().trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return item.targetType.label;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaClub = item.metadata['clubName']?.toString().trim() ?? '';
    if (metaClub.isNotEmpty) return Text(metaClub, style: style);
    final fallback = _fallback;
    if (fallback != item.targetType.label) {
      return Text(fallback, style: style);
    }
    if (item.targetType == SeriesApprovalTargetType.clubRegistration &&
        item.targetId.isNotEmpty) {
      final club = ref.watch(seriesClubByIdProvider(item.targetId)).valueOrNull;
      final name = club?.name.trim() ?? '';
      if (name.isNotEmpty) return Text(name, style: style);
    }
    return Text(fallback, style: style);
  }
}

/// Asks for a rejection reason (required). Returns null when cancelled.
Future<String?> askRejectionReason(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          key: const Key('reject_reason_field'),
          controller: controller,
          autofocus: true,
          maxLength: 300,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Shared with the requester',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('reject_reason_confirm'),
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    ),
  );
}

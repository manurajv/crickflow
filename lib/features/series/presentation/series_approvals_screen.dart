import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';
import 'widgets/series_user_name.dart';

class SeriesApprovalsScreen extends ConsumerWidget {
  const SeriesApprovalsScreen({super.key, required this.seriesId});
  final String seriesId;

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    SeriesApprovalModel approval,
    SeriesApprovalStatus decision,
  ) async {
    try {
      await ref.read(seriesApprovalRepositoryProvider).reviewSeriesApproval(
            seriesId: seriesId,
            approvalId: approval.id,
            decision: decision,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request ${decision.label.toLowerCase()}')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not review this request')),
        );
      }
    }
  }

  Future<void> _viewIdentity(
    BuildContext context,
    WidgetRef ref,
    SeriesApprovalModel approval,
  ) async {
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
            seriesId: seriesId,
            registrationId: registrationId,
          );
      if (!context.mounted) return;
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
                    children: map.entries.map((e) {
                      final value = e.value?.toString().trim() ?? '';
                      if (value.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${seriesIdentityFieldLabel(e.key)}: $value',
                        ),
                      );
                    }).toList(),
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
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load registration details')),
        );
      }
    }
  }

  String _subjectLabel(SeriesApprovalModel item) {
    final meta = item.metadata;
    final candidates = [
      meta['displayName']?.toString(),
      meta['clubName']?.toString(),
      meta['name']?.toString(),
      meta['clubAName']?.toString(),
      meta['title']?.toString(),
    ];
    for (final c in candidates) {
      final t = c?.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return item.targetType.label;
  }

  bool _canSeriesApprove(SeriesApprovalModel item, SeriesRole role) {
    if (item.targetType != SeriesApprovalTargetType.playerJoin) return true;
    final clubReview = item.metadata['clubReviewStatus']?.toString();
    if (clubReview == 'approved') return true;
    return role == SeriesRole.superAdmin;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final role = ref.watch(mySeriesRoleProvider(seriesId));
    if (role != SeriesRole.superAdmin && role != SeriesRole.seriesAdmin) {
      return const Scaffold(
        appBar: CfChromeAppBar(title: Text('Approvals')),
        body: Center(child: Text('Admin access required')),
      );
    }
    return Scaffold(
      backgroundColor: cf.background,
      appBar: const CfChromeAppBar(title: Text('Pending approvals')),
      body: ref.watch(pendingSeriesApprovalsProvider(seriesId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (items) => items.isEmpty
                ? const SeriesEmptyState(
                    icon: Icons.task_alt,
                    title: 'All caught up',
                    message: 'There are no pending approvals.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.spaceSm),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final subject = _subjectLabel(item);
                      final clubReviewRaw =
                          item.metadata['clubReviewStatus']?.toString();
                      final canApprove = _canSeriesApprove(item, role);
                      final hasRegistration =
                          item.metadata['registrationId'] != null ||
                          item.targetType ==
                              SeriesApprovalTargetType.playerRegistration;
                      return Card(
                        color: cf.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.spaceMd),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.targetType.label,
                                style: TextStyle(
                                  color: cf.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _ApprovalSubjectTitle(
                                item: item,
                                fallbackSubject: subject,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: cf.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Requested by ',
                                    style: TextStyle(color: cf.textSecondary),
                                  ),
                                  Flexible(
                                    child: SeriesUserName(
                                      item.requestedBy,
                                      fallback: 'Member',
                                      style: TextStyle(color: cf.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                              if (clubReviewRaw != null &&
                                  clubReviewRaw.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    seriesClubReviewLabel(clubReviewRaw),
                                    style: TextStyle(
                                      color: clubReviewRaw == 'approved'
                                          ? cf.success
                                          : cf.accent,
                                    ),
                                  ),
                                ),
                              if (!canApprove)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Waiting for club admin clearance',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cf.textSecondary,
                                    ),
                                  ),
                                ),
                              if (hasRegistration) ...[
                                const SizedBox(height: AppDimens.spaceSm),
                                TextButton.icon(
                                  onPressed: () =>
                                      _viewIdentity(context, ref, item),
                                  icon: const Icon(Icons.badge_outlined),
                                  label: const Text('View details'),
                                ),
                              ],
                              const SizedBox(height: AppDimens.spaceSm),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _review(
                                        context,
                                        ref,
                                        item,
                                        SeriesApprovalStatus.rejected,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: AppDimens.spaceSm),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: canApprove
                                          ? () => _review(
                                                context,
                                                ref,
                                                item,
                                                SeriesApprovalStatus.approved,
                                              )
                                          : null,
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
    );
  }
}

/// Black title line: prefers metadata name, else loads club name for club requests.
class _ApprovalSubjectTitle extends ConsumerWidget {
  const _ApprovalSubjectTitle({
    required this.item,
    required this.fallbackSubject,
    this.style,
  });

  final SeriesApprovalModel item;
  final String fallbackSubject;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaClub = item.metadata['clubName']?.toString().trim() ?? '';
    if (metaClub.isNotEmpty) {
      return Text(metaClub, style: style);
    }
    if (fallbackSubject != item.targetType.label) {
      return Text(fallbackSubject, style: style);
    }
    if (item.targetType == SeriesApprovalTargetType.clubRegistration &&
        item.targetId.isNotEmpty) {
      final club = ref.watch(seriesClubByIdProvider(item.targetId)).valueOrNull;
      final name = club?.name.trim() ?? '';
      if (name.isNotEmpty) {
        return Text(name, style: style);
      }
    }
    return Text(fallbackSubject, style: style);
  }
}

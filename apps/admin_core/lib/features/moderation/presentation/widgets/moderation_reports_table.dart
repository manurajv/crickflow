import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_moderation.dart';
import '../../models/moderation_enums.dart';
import 'moderation_status_badge.dart';

class ModerationReportsTable extends StatelessWidget {
  const ModerationReportsTable({
    super.key,
    required this.reports,
    required this.isLoading,
    required this.onResolve,
    required this.onDismiss,
    this.onOpenTarget,
    this.emptyTitle = 'No reports found',
    this.emptyMessage = 'Nothing to review in this section.',
  });

  final List<ManagedContentReport> reports;
  final bool isLoading;
  final Future<void> Function(ManagedContentReport report, {String? reason})
      onResolve;
  final Future<void> Function(ManagedContentReport report, {String? reason})
      onDismiss;
  final ValueChanged<ManagedContentReport>? onOpenTarget;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading && reports.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading reports…'),
        ),
      );
    }

    if (!isLoading && reports.isEmpty) {
      return CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.flag_outlined,
            title: emptyTitle,
            message: emptyMessage,
          ),
        ),
      );
    }

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < reports.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: context.adminColors.border),
            _ReportRow(
              report: reports[i],
              onResolve: onResolve,
              onDismiss: onDismiss,
              onOpenTarget: onOpenTarget,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '${reports.length} report(s)',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.adminColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.onResolve,
    required this.onDismiss,
    this.onOpenTarget,
  });

  final ManagedContentReport report;
  final Future<void> Function(ManagedContentReport report, {String? reason})
      onResolve;
  final Future<void> Function(ManagedContentReport report, {String? reason})
      onDismiss;
  final ValueChanged<ManagedContentReport>? onOpenTarget;

  String _shortId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 10)}…';
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required String title,
    required Future<void> Function(String? reason) run,
  }) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$title this report?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Resolution note (optional)',
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
    }
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final r = report;
    final dateFmt = DateFormat('MMM d HH:mm');
    final pending = r.status == ManagedReportStatus.pending ||
        r.status == ManagedReportStatus.reviewing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shortId(r.reporterUserId),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Reporter',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(r.targetType.label),
          ),
          Expanded(
            flex: 2,
            child: Text(
              r.reason.isEmpty ? '—' : r.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              r.details.isEmpty ? '—' : r.details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ModerationReportStatusBadge(status: r.status),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              r.createdAt == null ? '—' : dateFmt.format(r.createdAt!),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              if (onOpenTarget != null && r.postId.isNotEmpty)
                TextButton(
                  onPressed: () => onOpenTarget!(r),
                  child: const Text('Open'),
                ),
              if (pending) ...[
                TextButton(
                  onPressed: () => _confirmAction(
                    context,
                    title: 'Resolve',
                    run: (note) => onResolve(r, reason: note),
                  ),
                  child: const Text('Resolve'),
                ),
                TextButton(
                  onPressed: () => _confirmAction(
                    context,
                    title: 'Dismiss',
                    run: (note) => onDismiss(r, reason: note),
                  ),
                  child: Text(
                    'Dismiss',
                    style: TextStyle(color: colors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact pending reports list for overview section.
class ModerationPendingReportsList extends StatelessWidget {
  const ModerationPendingReportsList({
    super.key,
    required this.reports,
    required this.onResolve,
    required this.onDismiss,
    this.onOpenTarget,
  });

  final List<ManagedContentReport> reports;
  final Future<void> Function(ManagedContentReport report, {String? reason})
      onResolve;
  final Future<void> Function(ManagedContentReport report, {String? reason})
      onDismiss;
  final ValueChanged<ManagedContentReport>? onOpenTarget;

  @override
  Widget build(BuildContext context) {
    return ModerationReportsTable(
      reports: reports,
      isLoading: false,
      onResolve: onResolve,
      onDismiss: onDismiss,
      onOpenTarget: onOpenTarget,
      emptyTitle: 'No pending reports',
      emptyMessage: 'All caught up — no reports need review.',
    );
  }
}

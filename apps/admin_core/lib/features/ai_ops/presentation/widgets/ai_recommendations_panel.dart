import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/ai_ops_enums.dart';
import '../../models/managed_ai_ops.dart';
import 'ai_ops_summary_cards.dart';

class AiRecommendationsPanel extends StatelessWidget {
  const AiRecommendationsPanel({
    super.key,
    required this.items,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSelect,
    required this.onLoadMore,
    required this.onApprove,
    required this.onReject,
    required this.onArchive,
    this.onIgnoreDuplicate,
    this.onMarkValid,
    this.emptyTitle = 'No recommendations',
    this.emptyMessage =
        'Rules engine and future AI providers will populate this queue.',
  });

  final List<AiRecommendation> items;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<AiRecommendation> onSelect;
  final VoidCallback onLoadMore;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onArchive;
  final VoidCallback? onIgnoreDuplicate;
  final VoidCallback? onMarkValid;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    AiRecommendation? selected;
    for (final r in items) {
      if (r.id == selectedId) {
        selected = r;
        break;
      }
    }
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    if (isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfLoadingState(message: 'Loading recommendations…'),
        ),
      );
    }

    final list = items.isEmpty
        ? CfCard(
            child: SizedBox(
              height: 220,
              child: CfEmptyState(
                icon: Icons.auto_awesome,
                title: emptyTitle,
                message: emptyMessage,
              ),
            ),
          )
        : CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final r in items)
                  Material(
                    color: selectedId == r.id
                        ? context.adminColors.info.withValues(alpha: 0.08)
                        : null,
                    child: ListTile(
                      onTap: () => onSelect(r),
                      title: Text(r.title),
                      subtitle: Text(
                        '${r.category.label} · ${r.entityType.label}'
                        '${r.similarityPercent != null ? ' · ${r.similarityPercent!.toStringAsFixed(0)}% similar' : ''}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AiConfidenceBadge(score: r.confidence),
                          const SizedBox(height: 4),
                          AiStatusBadge(status: r.status),
                        ],
                      ),
                    ),
                  ),
                if (hasMore)
                  TextButton(
                    onPressed: isLoadingMore ? null : onLoadMore,
                    child: isLoadingMore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load more'),
                  ),
              ],
            ),
          );

    final detail = selected == null
        ? const SizedBox.shrink()
        : _RecDetail(
            rec: selected,
            onApprove: onApprove,
            onReject: onReject,
            onArchive: onArchive,
            onIgnoreDuplicate: onIgnoreDuplicate,
            onMarkValid: onMarkValid,
          );

    if (!wide || selected == null) {
      return Column(
        children: [
          list,
          if (selected != null) ...[
            const SizedBox(height: 12),
            detail,
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: list),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: detail),
      ],
    );
  }
}

class _RecDetail extends StatelessWidget {
  const _RecDetail({
    required this.rec,
    required this.onApprove,
    required this.onReject,
    required this.onArchive,
    this.onIgnoreDuplicate,
    this.onMarkValid,
  });

  final AiRecommendation rec;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onArchive;
  final VoidCallback? onIgnoreDuplicate;
  final VoidCallback? onMarkValid;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            rec.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AiConfidenceBadge(score: rec.confidence),
              AiStatusBadge(status: rec.status),
              Chip(label: Text(rec.category.label)),
              if (rec.reportPriority != null)
                Chip(label: Text('Priority ${rec.reportPriority!.label}')),
            ],
          ),
          const SizedBox(height: 12),
          Text(rec.reason),
          const SizedBox(height: 8),
          Text(
            'Suggested: ${rec.suggestedAction}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Entity: ${rec.entityType.label} ${rec.entityLabel.isEmpty ? rec.entityId : rec.entityLabel}',
            style: TextStyle(fontSize: 12, color: context.adminColors.textMuted),
          ),
          Text(
            'Provider: ${rec.provider.label}',
            style: TextStyle(fontSize: 12, color: context.adminColors.textMuted),
          ),
          if (rec.createdAt != null)
            Text(
              'Created ${fmt.format(rec.createdAt!)}',
              style:
                  TextStyle(fontSize: 12, color: context.adminColors.textMuted),
            ),
          const SizedBox(height: 8),
          Text(
            'AI never auto-modifies data — admin approval required.',
            style: TextStyle(
              fontSize: 11,
              color: context.adminColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (rec.status == AiRecommendationStatus.pending) ...[
                CfButton(label: 'Approve', onPressed: onApprove),
                OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Reject'),
                ),
              ],
              if (rec.category == AiRecommendationCategory.duplicate) ...[
                OutlinedButton(
                  onPressed: onIgnoreDuplicate,
                  child: const Text('Ignore'),
                ),
                OutlinedButton(
                  onPressed: onMarkValid,
                  child: const Text('Mark as Valid'),
                ),
                const Chip(label: Text('Merge (future)')),
              ],
              OutlinedButton(
                onPressed: onArchive,
                child: const Text('Archive'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

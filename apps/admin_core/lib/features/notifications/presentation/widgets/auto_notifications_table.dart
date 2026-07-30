import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_notification.dart';

class AutoNotificationsTable extends StatelessWidget {
  const AutoNotificationsTable({
    super.key,
    required this.items,
    required this.isLoading,
  });

  final List<ManagedAutoNotification> items;
  final bool isLoading;

  String _truncate(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 10)}…';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: colors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Monitoring only — automatic generation is unchanged',
                  style: TextStyle(
                    color: colors.info,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isLoading && items.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 280,
              child: CfLoadingState(message: 'Loading auto notifications…'),
            ),
          )
        else if (!isLoading && items.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 240,
              child: CfEmptyState(
                icon: Icons.auto_awesome_outlined,
                title: 'No auto notifications',
                message: 'System-generated inbox notifications will appear here.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  color: colors.background,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Title',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Type',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'User ID',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Match / Tournament',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Created',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Read',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.border),
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  _AutoRow(
                    item: items[i],
                    truncate: _truncate,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AutoRow extends StatelessWidget {
  const _AutoRow({required this.item, required this.truncate});

  final ManagedAutoNotification item;
  final String Function(String) truncate;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dateFmt = DateFormat('MMM d HH:mm');
    final matchOrTournament = item.matchId?.isNotEmpty == true
        ? truncate(item.matchId!)
        : item.tournamentId?.isNotEmpty == true
            ? truncate(item.tournamentId!)
            : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (item.body.isNotEmpty)
                  Text(
                    item.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.type ?? item.category ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              truncate(item.userId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(matchOrTournament),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.createdAt == null
                  ? '—'
                  : dateFmt.format(item.createdAt!),
            ),
          ),
          Expanded(
            child: Icon(
              item.read ? Icons.mark_email_read : Icons.mark_email_unread,
              size: 18,
              color: item.read ? colors.success : colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

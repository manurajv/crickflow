import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_notification.dart';
import '../../models/notification_enums.dart';
import 'notification_status_badge.dart';

class NotificationsTable extends StatefulWidget {
  const NotificationsTable({
    super.key,
    required this.campaigns,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
    this.showDeliveryMetrics = false,
    this.emptyTitle = 'No notifications found',
    this.emptyMessage = 'Try adjusting search or filters.',
  });

  final List<ManagedNotificationCampaign> campaigns;
  final NotificationSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<NotificationSortField> onSort;
  final ValueChanged<ManagedNotificationCampaign> onSelect;
  final VoidCallback onLoadMore;
  final bool showDeliveryMetrics;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<NotificationsTable> createState() => _NotificationsTableState();
}

class _NotificationsTableState extends State<NotificationsTable> {
  final _horizontalScroll = ScrollController();
  static const _tableWidth = 1280.0;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = widget.campaigns;

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading notifications…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.notifications_outlined,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          ),
        ),
      );
    }

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                controller: _horizontalScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SizedBox(
                      width: _tableWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Header(sort: widget.sort, onSort: widget.onSort),
                          Divider(height: 1, color: colors.border),
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: colors.border),
                            _NotificationRow(
                              campaign: items[i],
                              selected: items[i].id == widget.selectedId,
                              showDeliveryMetrics: widget.showDeliveryMetrics,
                              onTap: () => widget.onSelect(items[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  '${items.length} loaded',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.textSecondary),
                ),
                const Spacer(),
                if (widget.hasMore)
                  TextButton.icon(
                    onPressed: widget.isLoadingMore ? null : widget.onLoadMore,
                    icon: widget.isLoadingMore
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(
                      widget.isLoadingMore ? 'Loading…' : 'Load more',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sort, required this.onSort});

  final NotificationSort sort;
  final ValueChanged<NotificationSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _SortLabel('Title', NotificationSortField.title, sort, onSort,
              flex: 3),
          const _FlexCol('Category / Type', flex: 2),
          const _FlexCol('Audience', flex: 2),
          const _FlexCol('Sent By', flex: 2),
          _SortLabel('Created', NotificationSortField.createdAt, sort, onSort,
              flex: 2),
          _SortLabel('Status', NotificationSortField.status, sort, onSort,
              flex: 2),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SortLabel extends StatelessWidget {
  const _SortLabel(
    this.label,
    this.field,
    this.sort,
    this.onSort, {
    required this.flex,
  });

  final String label;
  final NotificationSortField field;
  final NotificationSort sort;
  final ValueChanged<NotificationSortField> onSort;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final active = sort.field == field;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(field),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 2),
              Icon(
                sort.descending ? Icons.arrow_downward : Icons.arrow_upward,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlexCol extends StatelessWidget {
  const _FlexCol(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _NotificationRow extends StatefulWidget {
  const _NotificationRow({
    required this.campaign,
    required this.selected,
    required this.showDeliveryMetrics,
    required this.onTap,
  });

  final ManagedNotificationCampaign campaign;
  final bool selected;
  final bool showDeliveryMetrics;
  final VoidCallback onTap;

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final c = widget.campaign;
    final bg = widget.selected
        ? AdminColors.primaryBlue.withValues(alpha: 0.08)
        : _hover
            ? colors.background
            : colors.card;
    final dateFmt = DateFormat('MMM d HH:mm');

    final sentBy = c.createdByEmail.isNotEmpty
        ? c.createdByEmail
        : (c.createdByUid.isNotEmpty ? c.createdByUid : '—');

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: bg,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (widget.showDeliveryMetrics &&
                          (c.deliveredCount > 0 ||
                              c.openedCount > 0 ||
                              c.clickedCount > 0))
                        Text(
                          'Delivered ${c.deliveredCount} · Opened ${c.openedCount} · Clicked ${c.clickedCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        )
                      else if (c.subtitle.isNotEmpty)
                        Text(
                          c.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: NotificationTypeBadge(type: c.type),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    c.audienceLabel.isNotEmpty
                        ? c.audienceLabel
                        : c.audience.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    sentBy,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    c.createdAt == null ? '—' : dateFmt.format(c.createdAt!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: NotificationStatusBadge(status: c.status),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    tooltip: 'View details',
                    onPressed: widget.onTap,
                    icon: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

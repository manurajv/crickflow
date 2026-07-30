import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/ads_enums.dart';
import '../../models/managed_ads.dart';
import 'ad_status_badge.dart';

class AdsTable extends StatefulWidget {
  const AdsTable({
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
    this.onDuplicate,
    this.onDelete,
    this.emptyTitle = 'No advertisements found',
    this.emptyMessage = 'Try adjusting search or filters.',
  });

  final List<ManagedAdCampaign> campaigns;
  final AdsSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<AdsSortField> onSort;
  final ValueChanged<ManagedAdCampaign> onSelect;
  final VoidCallback onLoadMore;
  final ValueChanged<ManagedAdCampaign>? onDuplicate;
  final ValueChanged<ManagedAdCampaign>? onDelete;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<AdsTable> createState() => _AdsTableState();
}

class _AdsTableState extends State<AdsTable> {
  final _horizontalScroll = ScrollController();
  static const _tableWidth = 1320.0;

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
          child: CfLoadingState(message: 'Loading advertisements…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.ads_click_outlined,
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
                            _AdRow(
                              campaign: items[i],
                              selected: items[i].id == widget.selectedId,
                              onTap: () => widget.onSelect(items[i]),
                              onDuplicate: widget.onDuplicate == null
                                  ? null
                                  : () => widget.onDuplicate!(items[i]),
                              onDelete: widget.onDelete == null
                                  ? null
                                  : () => widget.onDelete!(items[i]),
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

  final AdsSort sort;
  final ValueChanged<AdsSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _SortLabel('Title', AdsSortField.title, sort, onSort, flex: 3),
          const _FlexCol('Advertiser', flex: 2),
          const _FlexCol('Placement', flex: 2),
          _SortLabel('Status', AdsSortField.status, sort, onSort, flex: 2),
          _SortLabel('Start', AdsSortField.startDate, sort, onSort, flex: 2),
          const _FlexCol('End', flex: 2),
          const _FlexCol('Created By', flex: 2),
          const SizedBox(width: 72),
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
  final AdsSortField field;
  final AdsSort sort;
  final ValueChanged<AdsSortField> onSort;
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

class _AdRow extends StatefulWidget {
  const _AdRow({
    required this.campaign,
    required this.selected,
    required this.onTap,
    this.onDuplicate,
    this.onDelete,
  });

  final ManagedAdCampaign campaign;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  State<_AdRow> createState() => _AdRowState();
}

class _AdRowState extends State<_AdRow> {
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
    final dateFmt = DateFormat('MMM d, yyyy');

    final createdBy = c.createdByEmail.isNotEmpty
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
                      if (c.campaignName.isNotEmpty)
                        Text(
                          c.campaignName,
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
                  child: Text(
                    c.advertiserName.isNotEmpty ? c.advertiserName : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    c.placementLabel,
                    maxLines: 2,
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
                      child: AdStatusBadge(status: c.status),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    c.startDate == null ? '—' : dateFmt.format(c.startDate!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    c.endDate == null ? '—' : dateFmt.format(c.endDate!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    createdBy,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onDuplicate != null)
                        IconButton(
                          tooltip: 'Duplicate',
                          onPressed: widget.onDuplicate,
                          icon: Icon(
                            Icons.copy_outlined,
                            size: 18,
                            color: colors.textMuted,
                          ),
                        ),
                      IconButton(
                        tooltip: 'View details',
                        onPressed: widget.onTap,
                        icon: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
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

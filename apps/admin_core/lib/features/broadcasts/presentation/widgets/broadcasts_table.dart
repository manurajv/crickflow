import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/broadcast_enums.dart';
import '../../models/managed_broadcast.dart';
import 'broadcast_status_badge.dart';

class BroadcastsTable extends StatefulWidget {
  const BroadcastsTable({
    super.key,
    required this.broadcasts,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
  });

  final List<ManagedBroadcast> broadcasts;
  final BroadcastSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<BroadcastSortField> onSort;
  final ValueChanged<ManagedBroadcast> onSelect;
  final VoidCallback onLoadMore;

  @override
  State<BroadcastsTable> createState() => _BroadcastsTableState();
}

class _BroadcastsTableState extends State<BroadcastsTable> {
  final _horizontalScroll = ScrollController();
  static const _tableWidth = 1680.0;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = widget.broadcasts;

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading broadcasts…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.live_tv_outlined,
            title: 'No broadcasts found',
            message: 'Try adjusting search, filters, or live monitor mode.',
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
                            _BroadcastRow(
                              broadcast: items[i],
                              selected: items[i].id == widget.selectedId,
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

class BroadcastsLiveList extends StatelessWidget {
  const BroadcastsLiveList({
    super.key,
    required this.broadcasts,
    required this.isLoading,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ManagedBroadcast> broadcasts;
  final bool isLoading;
  final String? selectedId;
  final ValueChanged<ManagedBroadcast> onSelect;

  @override
  Widget build(BuildContext context) {
    if (isLoading && broadcasts.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading live broadcasts…'),
        ),
      );
    }

    if (!isLoading && broadcasts.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.sensors_outlined,
            title: 'No live broadcasts',
            message: 'Nothing is streaming right now.',
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final b in broadcasts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LiveCard(
              broadcast: b,
              selected: b.id == selectedId,
              onTap: () => onSelect(b),
            ),
          ),
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.broadcast,
    required this.selected,
    required this.onTap,
  });

  final ManagedBroadcast broadcast;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final b = broadcast;
    return CfCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.error.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.matchTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.teamsLabel,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      BroadcastStatusBadge(status: b.displayStatus),
                      BroadcastPlatformBadge(platform: b.platform),
                      BroadcastHealthBadge(health: b.health),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${b.viewerCount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'viewers',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  b.durationLabel,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: AdminColors.primaryBlue, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sort, required this.onSort});

  final BroadcastSort sort;
  final ValueChanged<BroadcastSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const _Col('ID', width: 88),
          _SortLabel('Match', BroadcastSortField.matchTitle, sort, onSort,
              flex: 3),
          _SortLabel('Platform', BroadcastSortField.platform, sort, onSort,
              flex: 2),
          _SortLabel('Status', BroadcastSortField.status, sort, onSort,
              flex: 2),
          const _FlexCol('Organizer', flex: 2),
          const _FlexCol('Tournament', flex: 2),
          const _FlexCol('Viewers', flex: 1),
          const _FlexCol('Health', flex: 2),
          _SortLabel('Started', BroadcastSortField.startedAt, sort, onSort,
              flex: 2),
          const _FlexCol('Duration', flex: 2),
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
  final BroadcastSortField field;
  final BroadcastSort sort;
  final ValueChanged<BroadcastSortField> onSort;
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

class _Col extends StatelessWidget {
  const _Col(this.label, {required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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

class _BroadcastRow extends StatefulWidget {
  const _BroadcastRow({
    required this.broadcast,
    required this.selected,
    required this.onTap,
  });

  final ManagedBroadcast broadcast;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_BroadcastRow> createState() => _BroadcastRowState();
}

class _BroadcastRowState extends State<_BroadcastRow> {
  bool _hover = false;

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  Future<void> _openWatchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final b = widget.broadcast;
    final bg = widget.selected
        ? AdminColors.primaryBlue.withValues(alpha: 0.08)
        : _hover
            ? colors.background
            : colors.card;
    final dateFmt = DateFormat('MMM d HH:mm');

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
                SizedBox(
                  width: 88,
                  child: Text(
                    _shortId(b.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.matchTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        b.teamsLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMuted, fontSize: 11),
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
                      child: BroadcastPlatformBadge(platform: b.platform),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BroadcastStatusBadge(status: b.displayStatus),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    b.organizerName.isEmpty ? '—' : b.organizerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    b.tournamentName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${b.viewerCount}', maxLines: 1),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BroadcastHealthBadge(health: b.health),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    b.streamStartedAt == null
                        ? '—'
                        : dateFmt.format(b.streamStartedAt!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    b.durationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    tooltip: b.watchUrl != null ? 'Open watch URL' : 'Open details',
                    onPressed: () {
                      if (b.watchUrl != null) {
                        _openWatchUrl(b.watchUrl);
                      } else {
                        widget.onTap();
                      }
                    },
                    icon: Icon(
                      Icons.open_in_new,
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

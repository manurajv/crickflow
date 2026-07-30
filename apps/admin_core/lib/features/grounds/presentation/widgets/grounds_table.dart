import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/ground_filters.dart';
import '../../models/managed_ground.dart';
import 'ground_status_badge.dart';

class GroundsTable extends StatefulWidget {
  const GroundsTable({
    super.key,
    required this.grounds,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
  });

  final List<ManagedGround> grounds;
  final GroundSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<GroundSortField> onSort;
  final ValueChanged<ManagedGround> onSelect;
  final VoidCallback onLoadMore;

  @override
  State<GroundsTable> createState() => _GroundsTableState();
}

class _GroundsTableState extends State<GroundsTable> {
  final _horizontalScroll = ScrollController();
  static const _tableWidth = 1420.0;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = widget.grounds;

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading grounds…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.stadium_outlined,
            title: 'No grounds found',
            message:
                'No tournament grounds yet. They appear from each tournament’s grounds list (not match venue). Adjust search/filters or create a tournament with grounds.',
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
                            _GroundRow(
                              ground: items[i],
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

class _Header extends StatelessWidget {
  const _Header({required this.sort, required this.onSort});

  final GroundSort sort;
  final ValueChanged<GroundSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 44),
          _SortLabel('Ground Name', GroundSortField.name, sort, onSort, flex: 3),
          const _Col('Ground ID', width: 100),
          _SortLabel('City', GroundSortField.city, sort, onSort, flex: 2),
          const _FlexCol('State', flex: 2),
          const _FlexCol('Country', flex: 2),
          const _FlexCol('Pitch', flex: 1),
          _SortLabel(
            'Matches',
            GroundSortField.matchesHosted,
            sort,
            onSort,
            flex: 1,
          ),
          _SortLabel('Rating', GroundSortField.rating, sort, onSort, flex: 1),
          const _FlexCol('Status', flex: 2),
          const _FlexCol('Verification', flex: 2),
          _SortLabel(
            'Created',
            GroundSortField.createdAt,
            sort,
            onSort,
            flex: 2,
          ),
          const SizedBox(width: 36),
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
  final GroundSortField field;
  final GroundSort sort;
  final ValueChanged<GroundSortField> onSort;
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

class _GroundRow extends StatefulWidget {
  const _GroundRow({
    required this.ground,
    required this.selected,
    required this.onTap,
  });

  final ManagedGround ground;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_GroundRow> createState() => _GroundRowState();
}

class _GroundRowState extends State<_GroundRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final g = widget.ground;
    final bg = widget.selected
        ? AdminColors.primaryBlue.withValues(alpha: 0.08)
        : _hover
            ? colors.background
            : colors.card;

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
                  width: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: g.photoUrl == null || g.photoUrl!.isEmpty
                        ? Container(
                            width: 36,
                            height: 36,
                            color: colors.background,
                            child: Icon(
                              Icons.stadium_outlined,
                              size: 18,
                              color: colors.textMuted,
                            ),
                          )
                        : Image.network(
                            g.photoUrl!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 36,
                              height: 36,
                              color: colors.background,
                              child: Icon(
                                Icons.stadium_outlined,
                                size: 18,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    g.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    g.city.isEmpty ? '—' : g.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    g.stateProvince.isEmpty ? '—' : g.stateProvince,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    g.country.isEmpty ? '—' : g.country,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    g.pitchType?.label ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${g.matchesHosted}', maxLines: 1),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    g.rating <= 0 ? '—' : g.rating.toStringAsFixed(1),
                    maxLines: 1,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: GroundStatusBadge(status: g.displayStatus),
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
                      child: GroundVerifiedBadge(verified: g.isVerified),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    g.createdAt == null
                        ? '—'
                        : DateFormat('yyyy-MM-dd').format(g.createdAt!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Icon(Icons.chevron_right, color: colors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_moderation.dart';
import '../../models/moderation_enums.dart';
import 'moderation_posts_table.dart' show ModerationPostAction, ModerationPostThumbnail;
import 'moderation_status_badge.dart';

class ModerationDiscoverTable extends StatefulWidget {
  const ModerationDiscoverTable({
    super.key,
    required this.posts,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
    this.onRemove,
    this.onRestore,
    this.onFeature,
  });

  final List<ManagedModerationPost> posts;
  final ModerationSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<ModerationSortField> onSort;
  final ValueChanged<ManagedModerationPost> onSelect;
  final VoidCallback onLoadMore;
  final ModerationPostAction? onRemove;
  final ModerationPostAction? onRestore;
  final Future<void> Function(ManagedModerationPost post, bool featured,
      {String? reason})? onFeature;

  @override
  State<ModerationDiscoverTable> createState() =>
      _ModerationDiscoverTableState();
}

class _ModerationDiscoverTableState extends State<ModerationDiscoverTable> {
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
    final items = widget.posts;

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading discover posts…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.explore_outlined,
            title: 'No discover posts found',
            message: 'Try adjusting search or filters.',
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
                            _DiscoverRow(
                              post: items[i],
                              selected: items[i].id == widget.selectedId,
                              onTap: () => widget.onSelect(items[i]),
                              onRemove: widget.onRemove,
                              onRestore: widget.onRestore,
                              onFeature: widget.onFeature,
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

  final ModerationSort sort;
  final ValueChanged<ModerationSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const _Col('Thumb', width: 52),
          _SortLabel('Author', ModerationSortField.author, sort, onSort,
              flex: 2),
          const _FlexCol('Category', flex: 2),
          const _FlexCol('Location', flex: 2),
          const _FlexCol('Contact', flex: 2),
          const _FlexCol('Status', flex: 2),
          _SortLabel('Created', ModerationSortField.createdAt, sort, onSort,
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
  final ModerationSortField field;
  final ModerationSort sort;
  final ValueChanged<ModerationSortField> onSort;
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

class _DiscoverRow extends StatefulWidget {
  const _DiscoverRow({
    required this.post,
    required this.selected,
    required this.onTap,
    this.onRemove,
    this.onRestore,
    this.onFeature,
  });

  final ManagedModerationPost post;
  final bool selected;
  final VoidCallback onTap;
  final ModerationPostAction? onRemove;
  final ModerationPostAction? onRestore;
  final Future<void> Function(ManagedModerationPost post, bool featured,
      {String? reason})? onFeature;

  @override
  State<_DiscoverRow> createState() => _DiscoverRowState();
}

class _DiscoverRowState extends State<_DiscoverRow> {
  bool _hover = false;

  String get _contactLabel {
    final p = widget.post;
    if (p.contactPhone.isNotEmpty) return p.contactPhone;
    if (p.contactWhatsApp.isNotEmpty) return p.contactWhatsApp;
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final p = widget.post;
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
                  width: 52,
                  child: ModerationPostThumbnail(url: p.thumbnailUrl, hasVideo: p.hasVideo),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.authorName.isEmpty ? 'Unknown' : p.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        p.displayTitle,
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
                    p.category.isEmpty ? '—' : p.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    p.locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _contactLabel,
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
                      child: ModerationPostStatusBadge(status: p.status),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    p.createdAt == null ? '—' : dateFmt.format(p.createdAt!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    tooltip: 'Open details',
                    onPressed: widget.onTap,
                    icon: Icon(Icons.open_in_new,
                        size: 18, color: colors.textMuted),
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_moderation.dart';
import '../../models/moderation_enums.dart';
import 'moderation_status_badge.dart';

typedef ModerationPostAction = Future<void> Function(
  ManagedModerationPost post, {
  String? reason,
});

class ModerationPostsTable extends StatefulWidget {
  const ModerationPostsTable({
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
    this.onHide,
    this.onRemove,
    this.onRestore,
    this.onFeature,
    this.emptyTitle = 'No posts found',
    this.emptyMessage = 'Try adjusting search or filters.',
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
  final ModerationPostAction? onHide;
  final ModerationPostAction? onRemove;
  final ModerationPostAction? onRestore;
  final Future<void> Function(ManagedModerationPost post, bool featured,
      {String? reason})? onFeature;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<ModerationPostsTable> createState() => _ModerationPostsTableState();
}

class _ModerationPostsTableState extends State<ModerationPostsTable> {
  final _horizontalScroll = ScrollController();
  static const _tableWidth = 1560.0;

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
          child: CfLoadingState(message: 'Loading posts…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.forum_outlined,
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
                            _PostRow(
                              post: items[i],
                              selected: items[i].id == widget.selectedId,
                              onTap: () => widget.onSelect(items[i]),
                              onHide: widget.onHide,
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
          const _FlexCol('Post Type', flex: 2),
          _SortLabel('Likes', ModerationSortField.likes, sort, onSort, flex: 1),
          _SortLabel('Comments', ModerationSortField.comments, sort, onSort,
              flex: 1),
          const _FlexCol('Shares', flex: 1),
          _SortLabel('Reports', ModerationSortField.reports, sort, onSort,
              flex: 1),
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

class _PostRow extends StatefulWidget {
  const _PostRow({
    required this.post,
    required this.selected,
    required this.onTap,
    this.onHide,
    this.onRemove,
    this.onRestore,
    this.onFeature,
  });

  final ManagedModerationPost post;
  final bool selected;
  final VoidCallback onTap;
  final ModerationPostAction? onHide;
  final ModerationPostAction? onRemove;
  final ModerationPostAction? onRestore;
  final Future<void> Function(ManagedModerationPost post, bool featured,
      {String? reason})? onFeature;

  @override
  State<_PostRow> createState() => _PostRowState();
}

class _PostRowState extends State<_PostRow> {
  bool _hover = false;

  String get _postTypeLabel {
    final p = widget.post;
    if (p.isTournamentPost) return 'Tournament';
    if (p.postKind.isNotEmpty) return p.postKind;
    if (p.category.isNotEmpty) return p.category;
    if (p.hasVideo) return 'Video';
    if (p.hasMedia) return 'Media';
    return 'Text';
  }

  Future<void> _runAction({
    required String title,
    required Future<void> Function(String? reason) run,
    bool danger = false,
  }) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Apply "$title" to this post?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
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
                    _postTypeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(flex: 1, child: Text('${p.likeCount}')),
                Expanded(flex: 1, child: Text('${p.commentCount}')),
                Expanded(flex: 1, child: Text('${p.shareCount}')),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${p.reportCount}',
                    style: p.reportCount > 0
                        ? TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w700,
                          )
                        : null,
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
                  child: PopupMenuButton<String>(
                    tooltip: 'Actions',
                    icon: Icon(Icons.more_vert, size: 18, color: colors.textMuted),
                    onSelected: (action) async {
                      switch (action) {
                        case 'open':
                          widget.onTap();
                        case 'hide':
                          if (widget.onHide != null) {
                            await _runAction(
                              title: 'Hide',
                              run: (r) => widget.onHide!(p, reason: r),
                            );
                          }
                        case 'remove':
                          if (widget.onRemove != null) {
                            await _runAction(
                              title: 'Remove',
                              run: (r) => widget.onRemove!(p, reason: r),
                              danger: true,
                            );
                          }
                        case 'restore':
                          if (widget.onRestore != null) {
                            await _runAction(
                              title: 'Restore',
                              run: (r) => widget.onRestore!(p, reason: r),
                            );
                          }
                        case 'feature':
                          if (widget.onFeature != null) {
                            await _runAction(
                              title: p.featured ? 'Unfeature' : 'Feature',
                              run: (r) =>
                                  widget.onFeature!(p, !p.featured, reason: r),
                            );
                          }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'open', child: Text('Open')),
                      if (widget.onHide != null &&
                          p.status != ManagedPostAdminStatus.hidden)
                        const PopupMenuItem(value: 'hide', child: Text('Hide')),
                      if (widget.onRemove != null &&
                          p.status != ManagedPostAdminStatus.removed)
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove'),
                        ),
                      if (widget.onRestore != null &&
                          (p.status == ManagedPostAdminStatus.removed ||
                              p.status == ManagedPostAdminStatus.hidden))
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Restore'),
                        ),
                      if (widget.onFeature != null)
                        PopupMenuItem(
                          value: 'feature',
                          child: Text(p.featured ? 'Unfeature' : 'Feature'),
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

class ModerationPostThumbnail extends StatelessWidget {
  const ModerationPostThumbnail({super.key, required this.url, required this.hasVideo});

  final String? url;
  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    if (url == null || url!.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Icon(Icons.image_outlined, size: 18, color: colors.textMuted),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Image.network(
            url!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 40,
              height: 40,
              color: colors.background,
              child: Icon(Icons.broken_image_outlined,
                  size: 18, color: colors.textMuted),
            ),
          ),
          if (hasVideo)
            Positioned(
              right: 2,
              bottom: 2,
              child: Icon(Icons.play_circle_fill,
                  size: 14, color: Colors.white.withValues(alpha: 0.9)),
            ),
        ],
      ),
    );
  }
}

/// Compact trending / overview list for posts.
class ModerationTrendingList extends StatelessWidget {
  const ModerationTrendingList({
    super.key,
    required this.posts,
    required this.onSelect,
    this.selectedId,
    this.title = 'Trending posts',
  });

  final List<ManagedModerationPost> posts;
  final ValueChanged<ManagedModerationPost> onSelect;
  final String? selectedId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    if (posts.isEmpty) {
      return CfCard(
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'No trending posts',
              style: TextStyle(color: colors.textMuted),
            ),
          ),
        ),
      );
    }

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Divider(height: 1, color: colors.border),
          for (var i = 0; i < posts.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.border),
            ListTile(
              dense: true,
              selected: posts[i].id == selectedId,
              leading: ModerationPostThumbnail(
                url: posts[i].thumbnailUrl,
                hasVideo: posts[i].hasVideo,
              ),
              title: Text(
                posts[i].displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${posts[i].authorName} · ${posts[i].likeCount} likes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '${posts[i].likeCount}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onTap: () => onSelect(posts[i]),
            ),
          ],
        ],
      ),
    );
  }
}

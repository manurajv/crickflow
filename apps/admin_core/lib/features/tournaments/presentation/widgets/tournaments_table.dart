import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_tournament.dart';
import '../../models/tournament_filters.dart';
import 'tournament_status_badge.dart';

class TournamentsTable extends StatefulWidget {
  const TournamentsTable({
    super.key,
    required this.tournaments,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
  });

  final List<ManagedTournament> tournaments;
  final TournamentSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<TournamentSortField> onSort;
  final ValueChanged<ManagedTournament> onSelect;
  final VoidCallback onLoadMore;

  @override
  State<TournamentsTable> createState() => _TournamentsTableState();
}

class _TournamentsTableState extends State<TournamentsTable> {
  final _horizontalScroll = ScrollController();

  static const _tableWidth = 1380.0;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = widget.tournaments;

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading tournaments…'),
        ),
      );
    }
    if (!widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'No tournaments found',
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
                    constraints:
                        BoxConstraints(minWidth: constraints.maxWidth),
                    child: SizedBox(
                      width: _tableWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Header(sort: widget.sort, onSort: widget.onSort),
                          Divider(height: 1, color: colors.border),
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: colors.border),
                            _TournamentRow(
                              tournament: items[i],
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
                const Spacer(),
                if (widget.hasMore)
                  TextButton.icon(
                    onPressed:
                        widget.isLoadingMore ? null : widget.onLoadMore,
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

  final TournamentSort sort;
  final ValueChanged<TournamentSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 52),
          _SortLabel('Name', TournamentSortField.name, sort, onSort, flex: 3),
          const _Col('Organizer', flex: 2),
          const _Col('Location', flex: 2),
          _SortLabel(
            'Start',
            TournamentSortField.startDate,
            sort,
            onSort,
            flex: 2,
          ),
          _SortLabel('End', TournamentSortField.endDate, sort, onSort, flex: 2),
          const _Col('Teams', flex: 1),
          const _Col('Matches', flex: 1),
          const _Col('Stage', flex: 2),
          _SortLabel(
            'Status',
            TournamentSortField.status,
            sort,
            onSort,
            flex: 2,
          ),
          _SortLabel(
            'Created',
            TournamentSortField.createdAt,
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
  final TournamentSortField field;
  final TournamentSort sort;
  final ValueChanged<TournamentSortField> onSort;
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
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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

class _Col extends StatelessWidget {
  const _Col(this.label, {required this.flex});

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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _TournamentRow extends StatefulWidget {
  const _TournamentRow({
    required this.tournament,
    required this.selected,
    required this.onTap,
  });

  final ManagedTournament tournament;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TournamentRow> createState() => _TournamentRowState();
}

class _TournamentRowState extends State<_TournamentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final t = widget.tournament;
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
                  width: 52,
                  height: 36,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: t.posterUrl.isEmpty
                        ? ColoredBox(
                            color: colors.background,
                            child: Icon(
                              Icons.emoji_events_outlined,
                              size: 18,
                              color: colors.textMuted,
                            ),
                          )
                        : Image.network(
                            t.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: colors.background,
                              child: Icon(
                                Icons.emoji_events_outlined,
                                size: 18,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        t.tournamentCode ?? t.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.organizerName.isEmpty
                        ? (t.effectiveOrganizerId.isEmpty
                            ? '—'
                            : t.effectiveOrganizerId)
                        : t.organizerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.startDate == null
                        ? '—'
                        : DateFormat('yyyy-MM-dd').format(t.startDate!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.endDate == null
                        ? '—'
                        : DateFormat('yyyy-MM-dd').format(t.endDate!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${t.teamCount}'),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${t.matchCount}'),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.currentStageLabel,
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
                      child: TournamentStatusBadge(status: t.status),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.createdAt == null
                        ? '—'
                        : DateFormat('yyyy-MM-dd').format(t.createdAt!),
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

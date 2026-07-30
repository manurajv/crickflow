import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_team.dart';
import '../../models/team_filters.dart';
import 'team_status_badge.dart';

class TeamsTable extends StatefulWidget {
  const TeamsTable({
    super.key,
    required this.teams,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
  });

  final List<ManagedTeam> teams;
  final TeamSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<TeamSortField> onSort;
  final ValueChanged<ManagedTeam> onSelect;
  final VoidCallback onLoadMore;

  @override
  State<TeamsTable> createState() => _TeamsTableState();
}

class _TeamsTableState extends State<TeamsTable> {
  final _horizontalScroll = ScrollController();
  static const _tableWidth = 1480.0;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = widget.teams;

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading teams…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.groups_outlined,
            title: 'No teams found',
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
                            _TeamRow(
                              team: items[i],
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

  final TeamSort sort;
  final ValueChanged<TeamSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 44),
          _SortLabel('Team Name', TeamSortField.name, sort, onSort, flex: 3),
          const _Col('Team ID', width: 100),
          const _FlexCol('Captain', flex: 2),
          const _FlexCol('Manager', flex: 2),
          _SortLabel('Members', TeamSortField.members, sort, onSort, flex: 1),
          const _FlexCol('Followers', flex: 1),
          _SortLabel('Matches', TeamSortField.matches, sort, onSort, flex: 1),
          _SortLabel('Win %', TeamSortField.winPct, sort, onSort, flex: 1),
          const _FlexCol('Status', flex: 2),
          const _FlexCol('Verification', flex: 2),
          _SortLabel(
            'Created',
            TeamSortField.createdAt,
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
  final TeamSortField field;
  final TeamSort sort;
  final ValueChanged<TeamSortField> onSort;
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

class _TeamRow extends StatefulWidget {
  const _TeamRow({
    required this.team,
    required this.selected,
    required this.onTap,
  });

  final ManagedTeam team;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TeamRow> createState() => _TeamRowState();
}

class _TeamRowState extends State<_TeamRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final t = widget.team;
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
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.background,
                    child: t.logoUrl == null || t.logoUrl!.isEmpty
                        ? Icon(Icons.groups, size: 16, color: colors.textMuted)
                        : ClipOval(
                            child: Image.network(
                              t.logoUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.groups,
                                size: 16,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    t.shortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.captainId ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    t.createdBy ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${t.memberCount}', maxLines: 1),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${t.followersCount}', maxLines: 1),
                ),
                Expanded(
                  flex: 1,
                  child: Text('${t.matchesPlayed}', maxLines: 1),
                ),
                Expanded(
                  flex: 1,
                  child: Text(t.winPctLabel, maxLines: 1),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: TeamStatusBadge(status: t.displayStatus),
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
                      child: TeamVerifiedBadge(verified: t.isVerified),
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

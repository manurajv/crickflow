import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/managed_support.dart';
import '../../models/support_enums.dart';
import 'support_badges.dart';

class SupportTicketsTable extends StatefulWidget {
  const SupportTicketsTable({
    super.key,
    required this.tickets,
    required this.sort,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSort,
    required this.onSelect,
    required this.onLoadMore,
    this.emptyTitle = 'No tickets found',
    this.emptyMessage = 'Create a ticket or adjust filters.',
  });

  final List<ManagedSupportTicket> tickets;
  final SupportSort sort;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<SupportSortField> onSort;
  final ValueChanged<ManagedSupportTicket> onSelect;
  final VoidCallback onLoadMore;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<SupportTicketsTable> createState() => _SupportTicketsTableState();
}

class _SupportTicketsTableState extends State<SupportTicketsTable> {
  final _horizontal = ScrollController();
  static const _width = 1320.0;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = widget.tickets;
    final fmt = DateFormat.yMMMd().add_jm();

    if (widget.isLoading && items.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading tickets…'),
        ),
      );
    }

    if (!widget.isLoading && items.isEmpty) {
      return CfCard(
        child: SizedBox(
          height: 240,
          child: CfEmptyState(
            icon: Icons.support_agent_outlined,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          ),
        ),
      );
    }

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _width,
                child: Column(
                  children: [
                    Material(
                      color: colors.background,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            _H('Ticket ID', 110),
                            _H('Subject', 220),
                            _H('Category', 120),
                            _H('Priority', 100),
                            _H('Status', 140),
                            _H('Created By', 160),
                            _H('Assigned To', 140),
                            _H('Created', 140),
                            _H('Updated', 140),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    for (final t in items)
                      Material(
                        color: widget.selectedId == t.id
                            ? AdminColors.primaryBlue.withValues(alpha: 0.08)
                            : null,
                        child: InkWell(
                          onTap: () => widget.onSelect(t),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                _C(t.ticketNumber, 110, bold: true),
                                _C(t.subject, 220),
                                _C(t.category.label, 120),
                                SizedBox(
                                  width: 100,
                                  child: SupportPriorityBadge(
                                    priority: t.priority,
                                  ),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: SupportStatusBadge(status: t.status),
                                ),
                                _C(t.createdByEmail, 160),
                                _C(t.assignedToName ?? '—', 140),
                                _C(
                                  t.createdAt == null
                                      ? '—'
                                      : fmt.format(t.createdAt!),
                                  140,
                                ),
                                _C(
                                  t.updatedAt == null
                                      ? '—'
                                      : fmt.format(t.updatedAt!),
                                  140,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.hasMore)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: widget.isLoadingMore ? null : widget.onLoadMore,
                child: widget.isLoadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.label, this.width);
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: context.adminColors.textMuted,
        ),
      ),
    );
  }
}

class _C extends StatelessWidget {
  const _C(this.text, this.width, {this.bold = false});
  final String text;
  final double width;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

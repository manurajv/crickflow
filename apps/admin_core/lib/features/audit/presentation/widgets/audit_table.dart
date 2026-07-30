import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/audit_log_view.dart';
import 'audit_chrome.dart';

class AuditLogsTable extends StatefulWidget {
  const AuditLogsTable({
    super.key,
    required this.logs,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    required this.selectedId,
    required this.onSelect,
    required this.onLoadMore,
  });

  final List<AuditLogView> logs;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? selectedId;
  final ValueChanged<AuditLogView> onSelect;
  final VoidCallback onLoadMore;

  @override
  State<AuditLogsTable> createState() => _AuditLogsTableState();
}

class _AuditLogsTableState extends State<AuditLogsTable> {
  final _hScroll = ScrollController();
  static const _width = 1400.0;

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    if (widget.isLoading && widget.logs.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 260,
          child: CfLoadingState(message: 'Loading audit logs…'),
        ),
      );
    }
    if (!widget.isLoading && widget.logs.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 220,
          child: CfEmptyState(
            icon: Icons.history,
            title: 'No audit logs found',
            message: 'Adjust filters or wait for administrative activity.',
          ),
        ),
      );
    }

    final df = DateFormat.yMMMd().add_jm();

    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                controller: _hScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SizedBox(
                      width: _width,
                      child: Column(
                        children: [
                          ColoredBox(
                            color: colors.background,
                            child: const Row(
                              children: [
                                _H('Timestamp', flex: 14),
                                _H('Action', flex: 16),
                                _H('Module', flex: 10),
                                _H('Performed By', flex: 14),
                                _H('Target', flex: 12),
                                _H('Severity', flex: 9),
                                _H('Status', flex: 9),
                                _H('Platform', flex: 8),
                                _H('', flex: 6),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: colors.border),
                          for (var i = 0; i < widget.logs.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: colors.border),
                            _Row(
                              log: widget.logs[i],
                              selected: widget.logs[i].id == widget.selectedId,
                              timestamp: df.format(widget.logs[i].timestamp),
                              onTap: () => widget.onSelect(widget.logs[i]),
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
                  '${widget.logs.length} shown',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
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
                        : const Icon(Icons.expand_more, size: 18),
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

class _H extends StatelessWidget {
  const _H(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: context.adminColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.log,
    required this.selected,
    required this.timestamp,
    required this.onTap,
  });

  final AuditLogView log;
  final bool selected;
  final String timestamp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Material(
      color: selected
          ? AdminColors.primaryBlue.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(timestamp, style: const TextStyle(fontSize: 12)),
                ),
              ),
              Expanded(
                flex: 16,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    log.actionLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AuditModuleBadge(module: log.module),
                ),
              ),
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    log.actorEmail.isEmpty ? log.actorUid : log.actorEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    log.targetLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ),
              ),
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AuditSeverityBadge(severity: log.severity),
                ),
              ),
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AuditStatusBadge(status: log.status),
                ),
              ),
              Expanded(
                flex: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    log.platform.isEmpty ? '—' : log.platform,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: IconButton(
                  tooltip: 'Open details',
                  onPressed: onTap,
                  icon: const Icon(Icons.open_in_new, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

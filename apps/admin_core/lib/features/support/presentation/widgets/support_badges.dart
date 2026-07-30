import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/support_enums.dart';

class SupportStatusBadge extends StatelessWidget {
  const SupportStatusBadge({super.key, required this.status});

  final SupportTicketStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      SupportTicketStatus.open => AdminColors.primaryBlue,
      SupportTicketStatus.assigned => colors.warning,
      SupportTicketStatus.inProgress => colors.warning,
      SupportTicketStatus.waitingForUser => colors.textMuted,
      SupportTicketStatus.waitingForInternal => colors.textMuted,
      SupportTicketStatus.resolved => colors.success,
      SupportTicketStatus.closed => colors.textMuted,
      SupportTicketStatus.rejected => colors.error,
      SupportTicketStatus.duplicate => colors.textMuted,
    };
    return _Pill(label: status.label, color: color);
  }
}

class SupportPriorityBadge extends StatelessWidget {
  const SupportPriorityBadge({super.key, required this.priority});

  final SupportTicketPriority priority;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (priority) {
      SupportTicketPriority.low => colors.textMuted,
      SupportTicketPriority.medium => AdminColors.primaryBlue,
      SupportTicketPriority.high => colors.warning,
      SupportTicketPriority.critical => colors.error,
    };
    return _Pill(label: priority.label, color: color);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

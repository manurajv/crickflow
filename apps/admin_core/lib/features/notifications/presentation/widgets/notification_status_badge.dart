import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/notification_enums.dart';

class NotificationStatusBadge extends StatelessWidget {
  const NotificationStatusBadge({super.key, required this.status});

  final ManagedNotificationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedNotificationStatus.draft => colors.textMuted,
      ManagedNotificationStatus.scheduled => AdminColors.primaryBlue,
      ManagedNotificationStatus.sending => colors.info,
      ManagedNotificationStatus.queued => colors.warning,
      ManagedNotificationStatus.sent => colors.success,
      ManagedNotificationStatus.failed => colors.error,
      ManagedNotificationStatus.cancelled => colors.textMuted,
      ManagedNotificationStatus.archived => colors.textSecondary,
    };
    return _Pill(label: status.label, color: color);
  }
}

class NotificationTypeBadge extends StatelessWidget {
  const NotificationTypeBadge({super.key, required this.type});

  final ManagedNotificationType type;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (type) {
      ManagedNotificationType.announcement => AdminColors.primaryBlue,
      ManagedNotificationType.match => colors.success,
      ManagedNotificationType.tournament => const Color(0xFF7E57C2),
      ManagedNotificationType.system => colors.textMuted,
      ManagedNotificationType.community => colors.info,
      ManagedNotificationType.discover => const Color(0xFF00897B),
      ManagedNotificationType.promotion => colors.warning,
      ManagedNotificationType.reminder => colors.info,
      ManagedNotificationType.campaign => const Color(0xFFE65100),
    };
    return _Pill(label: type.label, color: color);
  }
}

class NotificationAudienceBadge extends StatelessWidget {
  const NotificationAudienceBadge({super.key, required this.audience});

  final ManagedNotificationAudience audience;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: audience.label,
      color: context.adminColors.info,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

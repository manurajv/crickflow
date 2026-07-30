import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/moderation_enums.dart';

class ModerationPostStatusBadge extends StatelessWidget {
  const ModerationPostStatusBadge({super.key, required this.status});

  final ManagedPostAdminStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedPostAdminStatus.published => colors.success,
      ManagedPostAdminStatus.pending => colors.warning,
      ManagedPostAdminStatus.hidden => colors.info,
      ManagedPostAdminStatus.removed => colors.error,
      ManagedPostAdminStatus.reported => colors.error,
      ManagedPostAdminStatus.archived => colors.textMuted,
    };
    return _Pill(label: status.label, color: color);
  }
}

class ModerationReportStatusBadge extends StatelessWidget {
  const ModerationReportStatusBadge({super.key, required this.status});

  final ManagedReportStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedReportStatus.pending => colors.warning,
      ManagedReportStatus.reviewing => AdminColors.primaryBlue,
      ManagedReportStatus.resolved => colors.success,
      ManagedReportStatus.dismissed => colors.textMuted,
    };
    return _Pill(label: status.label, color: color);
  }
}

class ModerationSourceBadge extends StatelessWidget {
  const ModerationSourceBadge({super.key, required this.source});

  final ModerationSource source;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (source) {
      ModerationSource.community => AdminColors.primaryBlue,
      ModerationSource.discover => const Color(0xFF00897B),
      ModerationSource.report => colors.warning,
      ModerationSource.chat => colors.info,
    };
    final label = switch (source) {
      ModerationSource.community => 'Community',
      ModerationSource.discover => 'Discover',
      ModerationSource.report => 'Report',
      ModerationSource.chat => 'Chat',
    };
    return _Pill(label: label, color: color);
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

import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/tournament_enums.dart';

class TournamentStatusBadge extends StatelessWidget {
  const TournamentStatusBadge({super.key, required this.status});

  final ManagedTournamentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedTournamentStatus.draft => colors.textMuted,
      ManagedTournamentStatus.upcoming => colors.info,
      ManagedTournamentStatus.live => colors.success,
      ManagedTournamentStatus.completed => AdminColors.primaryBlue,
      ManagedTournamentStatus.cancelled => colors.error,
    };
    return _Pill(label: status.label, color: color);
  }
}

class TournamentFeaturedBadge extends StatelessWidget {
  const TournamentFeaturedBadge({super.key, required this.featured});

  final bool featured;

  @override
  Widget build(BuildContext context) {
    if (!featured) return const SizedBox.shrink();
    return _Pill(
      label: 'Featured',
      color: context.adminColors.warning,
    );
  }
}

class TournamentApprovalBadge extends StatelessWidget {
  const TournamentApprovalBadge({super.key, required this.approval});

  final AdminTournamentApproval approval;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (approval) {
      AdminTournamentApproval.pending => colors.warning,
      AdminTournamentApproval.approved => colors.success,
      AdminTournamentApproval.rejected => colors.error,
    };
    return _Pill(label: approval.label, color: color);
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

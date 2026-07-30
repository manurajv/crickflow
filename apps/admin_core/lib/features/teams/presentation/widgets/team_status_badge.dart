import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/team_enums.dart';

class TeamStatusBadge extends StatelessWidget {
  const TeamStatusBadge({super.key, required this.status});

  final ManagedTeamStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedTeamStatus.active => colors.success,
      ManagedTeamStatus.pendingVerification => colors.warning,
      ManagedTeamStatus.verified => AdminColors.primaryBlue,
      ManagedTeamStatus.suspended => colors.error,
      ManagedTeamStatus.archived => colors.textMuted,
      ManagedTeamStatus.deleted => colors.error,
    };
    return _Pill(label: status.label, color: color);
  }
}

class TeamVerifiedBadge extends StatelessWidget {
  const TeamVerifiedBadge({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: verified ? 'Verified' : 'Unverified',
      color: verified
          ? context.adminColors.success
          : context.adminColors.textMuted,
    );
  }
}

class TeamFeaturedBadge extends StatelessWidget {
  const TeamFeaturedBadge({super.key, required this.featured});

  final bool featured;

  @override
  Widget build(BuildContext context) {
    if (!featured) return const SizedBox.shrink();
    return _Pill(label: 'Featured', color: context.adminColors.warning);
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

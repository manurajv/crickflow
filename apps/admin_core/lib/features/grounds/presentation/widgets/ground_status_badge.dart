import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/ground_enums.dart';

class GroundStatusBadge extends StatelessWidget {
  const GroundStatusBadge({super.key, required this.status});

  final ManagedGroundStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedGroundStatus.active => colors.success,
      ManagedGroundStatus.pendingVerification => colors.warning,
      ManagedGroundStatus.verified => AdminColors.primaryBlue,
      ManagedGroundStatus.suspended => colors.error,
      ManagedGroundStatus.archived => colors.textMuted,
      ManagedGroundStatus.deleted => colors.error,
    };
    return _Pill(label: status.label, color: color);
  }
}

class GroundVerifiedBadge extends StatelessWidget {
  const GroundVerifiedBadge({super.key, required this.verified});

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

class GroundFeaturedBadge extends StatelessWidget {
  const GroundFeaturedBadge({super.key, required this.featured});

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

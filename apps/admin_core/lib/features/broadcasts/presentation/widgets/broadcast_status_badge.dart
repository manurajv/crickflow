import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../matches/models/match_enums.dart';
import '../../models/broadcast_enums.dart';

class BroadcastStatusBadge extends StatelessWidget {
  const BroadcastStatusBadge({super.key, required this.status});

  final ManagedBroadcastStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedBroadcastStatus.live => colors.error,
      ManagedBroadcastStatus.connecting => colors.warning,
      ManagedBroadcastStatus.reconnecting => colors.warning,
      ManagedBroadcastStatus.scheduled => AdminColors.primaryBlue,
      ManagedBroadcastStatus.waiting => colors.info,
      ManagedBroadcastStatus.completed => colors.success,
      ManagedBroadcastStatus.failed => colors.error,
      ManagedBroadcastStatus.cancelled => colors.textMuted,
      ManagedBroadcastStatus.idle => colors.textMuted,
    };
    return _Pill(label: status.label, color: color);
  }
}

class BroadcastHealthBadge extends StatelessWidget {
  const BroadcastHealthBadge({super.key, required this.health});

  final ManagedBroadcastHealth health;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (health) {
      ManagedBroadcastHealth.healthy => colors.success,
      ManagedBroadcastHealth.poor => colors.warning,
      ManagedBroadcastHealth.offline => colors.error,
      ManagedBroadcastHealth.unknown => colors.textMuted,
    };
    return _Pill(label: health.label, color: color);
  }
}

class BroadcastPlatformBadge extends StatelessWidget {
  const BroadcastPlatformBadge({super.key, required this.platform});

  final ManagedStreamPlatform platform;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (platform) {
      ManagedStreamPlatform.youtube => const Color(0xFFFF0000),
      ManagedStreamPlatform.facebook => const Color(0xFF1877F2),
      ManagedStreamPlatform.externalRtmp => const Color(0xFF7E57C2),
      ManagedStreamPlatform.none => colors.textMuted,
      ManagedStreamPlatform.other => colors.info,
    };
    return _Pill(label: platform.label, color: color);
  }
}

class BroadcastFeaturedBadge extends StatelessWidget {
  const BroadcastFeaturedBadge({super.key, required this.featured});

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

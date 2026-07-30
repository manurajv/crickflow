import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/match_enums.dart';

class MatchStatusBadge extends StatelessWidget {
  const MatchStatusBadge({super.key, required this.status});

  final ManagedMatchStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedMatchStatus.draft => colors.textMuted,
      ManagedMatchStatus.scheduled => colors.info,
      ManagedMatchStatus.tossCompleted => colors.warning,
      ManagedMatchStatus.live => colors.success,
      ManagedMatchStatus.inningsBreak => const Color(0xFF26A69A),
      ManagedMatchStatus.completed => AdminColors.primaryBlue,
      ManagedMatchStatus.abandoned => colors.error,
      ManagedMatchStatus.cancelled => colors.error,
      ManagedMatchStatus.delayed => colors.warning,
    };
    return _Pill(label: status.label, color: color);
  }
}

class MatchStreamingBadge extends StatelessWidget {
  const MatchStreamingBadge({
    super.key,
    required this.isStreaming,
    required this.platform,
  });

  final bool isStreaming;
  final ManagedStreamPlatform platform;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: isStreaming ? platform.label : 'No Stream',
      color: isStreaming
          ? context.adminColors.success
          : context.adminColors.textMuted,
    );
  }
}

class MatchFeaturedBadge extends StatelessWidget {
  const MatchFeaturedBadge({super.key, required this.featured});

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

import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/ads_enums.dart';

class AdStatusBadge extends StatelessWidget {
  const AdStatusBadge({super.key, required this.status});

  final ManagedAdStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      ManagedAdStatus.draft => colors.textMuted,
      ManagedAdStatus.pendingApproval => colors.warning,
      ManagedAdStatus.approved => AdminColors.primaryBlue,
      ManagedAdStatus.rejected => colors.error,
      ManagedAdStatus.scheduled => AdminColors.primaryBlue,
      ManagedAdStatus.active => colors.success,
      ManagedAdStatus.paused => colors.info,
      ManagedAdStatus.archived => colors.textSecondary,
      ManagedAdStatus.expired => colors.textMuted,
    };
    return _Pill(label: status.label, color: color);
  }
}

class AdMediaTypeBadge extends StatelessWidget {
  const AdMediaTypeBadge({super.key, required this.mediaType});

  final ManagedAdMediaType mediaType;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (mediaType) {
      ManagedAdMediaType.image => AdminColors.primaryBlue,
      ManagedAdMediaType.video => const Color(0xFF7E57C2),
      ManagedAdMediaType.gif => colors.warning,
      ManagedAdMediaType.carousel => colors.info,
    };
    return _Pill(label: mediaType.label, color: color);
  }
}

class AdCampaignTypeBadge extends StatelessWidget {
  const AdCampaignTypeBadge({super.key, required this.campaignType});

  final ManagedAdCampaignType campaignType;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: campaignType.label,
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

import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/user_account_status.dart';

class UserStatusBadge extends StatelessWidget {
  const UserStatusBadge({super.key, required this.status});

  final UserAccountStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      UserAccountStatus.active => colors.success,
      UserAccountStatus.suspended => colors.warning,
      UserAccountStatus.banned => colors.error,
      UserAccountStatus.deleted => colors.textMuted,
      UserAccountStatus.pendingVerification => colors.info,
      UserAccountStatus.inactive => colors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
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

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = verified ? colors.success : colors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified : Icons.verified_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Yes' : 'No',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../models/organization_enums.dart';

class OrganizationStatusBadge extends StatelessWidget {
  const OrganizationStatusBadge({super.key, required this.status});

  final ManagedOrganizationStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final (color, icon) = switch (status) {
      ManagedOrganizationStatus.active => (colors.success, Icons.check_circle_outline),
      ManagedOrganizationStatus.pending => (colors.warning, Icons.hourglass_empty_outlined),
      ManagedOrganizationStatus.verified => (AdminColors.primaryBlue, Icons.verified_outlined),
      ManagedOrganizationStatus.inactive => (colors.textMuted, Icons.pause_circle_outline),
      ManagedOrganizationStatus.suspended => (colors.error, Icons.block_outlined),
      ManagedOrganizationStatus.archived => (const Color(0xFF78909C), Icons.archive_outlined),
      ManagedOrganizationStatus.deleted => (colors.error, Icons.delete_outline),
    };
    return _Pill(label: status.label, color: color, icon: icon);
  }
}

class OrganizationTypeBadge extends StatelessWidget {
  const OrganizationTypeBadge({super.key, required this.type, this.compact = false});

  final ManagedOrganizationType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return _Pill(
      label: compact ? type.shortLabel : type.label,
      color: color,
    );
  }

  Color _typeColor(ManagedOrganizationType t) {
    return switch (t) {
      ManagedOrganizationType.nationalBoard => const Color(0xFF1565C0),
      ManagedOrganizationType.provincialBoard => const Color(0xFF1976D2),
      ManagedOrganizationType.districtAssociation => const Color(0xFF1E88E5),
      ManagedOrganizationType.club => const Color(0xFF00897B),
      ManagedOrganizationType.academy => const Color(0xFF2E7D32),
      ManagedOrganizationType.school => const Color(0xFFAD1457),
      ManagedOrganizationType.university => const Color(0xFF6A1B9A),
      ManagedOrganizationType.corporate => const Color(0xFF37474F),
      ManagedOrganizationType.league => const Color(0xFFE65100),
      ManagedOrganizationType.tournamentOrganizer => const Color(0xFFBF360C),
      ManagedOrganizationType.privateGroup => const Color(0xFF4527A0),
      ManagedOrganizationType.other => const Color(0xFF546E7A),
    };
  }
}

class OrganizationFeaturedBadge extends StatelessWidget {
  const OrganizationFeaturedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Pill(
      label: 'Featured',
      color: Color(0xFFF9A825),
      icon: Icons.star_outline,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/admin_app_type.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/dashboard_providers.dart';

class DashboardWelcomeHeader extends ConsumerWidget {
  const DashboardWelcomeHeader({
    super.key,
    required this.scopeLabel,
    required this.isOrganizationScoped,
    required this.onRefresh,
    this.refreshing = false,
  });

  final String scopeLabel;
  final bool isOrganizationScoped;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final admin = ref.watch(adminSessionProvider).adminUser;
    final now = ref.watch(dashboardNowProvider).asData?.value ?? DateTime.now();
    final name = admin?.displayName?.split(' ').first ??
        admin?.email.split('@').first ??
        'Admin';
    final greeting = _greeting(now);
    final dateLabel = DateFormat('EEEE, d MMMM yyyy').format(now);
    final timeLabel = DateFormat('h:mm a').format(now);
    final appType = ref.watch(adminAppTypeProvider);

    return CfCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $name',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  appType == AdminAppType.superAdmin
                      ? "Welcome back, $name.\nHere's what's happening across CrickFlow today."
                      : "Welcome back, $name.\nHere's what's happening in $scopeLabel today.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: dateLabel,
                    ),
                    _MetaChip(
                      icon: Icons.access_time,
                      label: timeLabel,
                    ),
                    _MetaChip(
                      icon: isOrganizationScoped
                          ? Icons.business_outlined
                          : Icons.public_outlined,
                      label: scopeLabel,
                      accent: AdminColors.primaryBlue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CfButton(
            label: refreshing ? 'Refreshing' : 'Refresh',
            icon: Icons.refresh,
            variant: CfButtonVariant.secondary,
            isLoading: refreshing,
            onPressed: refreshing ? null : onRefresh,
          ),
        ],
      ),
    );
  }

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = accent ?? colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

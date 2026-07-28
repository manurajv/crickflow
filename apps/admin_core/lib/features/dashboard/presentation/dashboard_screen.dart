import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_chart_placeholder.dart';
import '../../../shared/widgets/cf_stat_tile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = ['Dashboard'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final appType = ref.watch(adminAppTypeProvider);
    final admin = ref.watch(adminSessionProvider).adminUser;
    final colors = context.adminColors;

    return PermissionGate(
      permission: AdminPermission.canViewDashboard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1400
              ? 4
              : width >= 1000
                  ? 3
                  : width >= 700
                      ? 2
                      : 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome${admin?.displayName != null ? ', ${admin!.displayName}' : ''}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  appType == AdminAppType.superAdmin
                      ? 'Platform overview — placeholder metrics for foundation phase.'
                      : 'Organization overview — scoped to your organization only.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
                if (admin?.organizationName != null) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.business, size: 16),
                    label: Text(admin!.organizationName!),
                  ),
                ],
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.55,
                  children: [
                    for (final card in _placeholderCards(appType))
                      CfStatTile(
                        icon: card.icon,
                        title: card.title,
                        value: card.value,
                        growthLabel: card.growth,
                        growthPositive: card.positive,
                        accentColor: card.color,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (width >= 1000)
                  const Row(
                    children: [
                      Expanded(
                        child: CfChartPlaceholder(title: 'Activity (placeholder)'),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: CfChartPlaceholder(
                          title: 'Engagement (placeholder)',
                        ),
                      ),
                    ],
                  )
                else ...[
                  const CfChartPlaceholder(title: 'Activity (placeholder)'),
                  const SizedBox(height: 16),
                  const CfChartPlaceholder(title: 'Engagement (placeholder)'),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<_DashCard> _placeholderCards(AdminAppType type) {
    final base = <_DashCard>[
      const _DashCard(
        icon: Icons.people_outline,
        title: 'Users',
        value: '—',
        growth: '+0%',
        positive: true,
        color: AdminColors.primaryBlue,
      ),
      const _DashCard(
        icon: Icons.sports_cricket_outlined,
        title: 'Matches',
        value: '—',
        growth: '+0%',
        positive: true,
        color: AdminColors.goldDark,
      ),
      const _DashCard(
        icon: Icons.groups_outlined,
        title: 'Teams',
        value: '—',
        growth: '+0%',
        positive: true,
        color: Color(0xFF7E57C2),
      ),
      const _DashCard(
        icon: Icons.person_outline,
        title: 'Players',
        value: '—',
        growth: '+0%',
        positive: true,
        color: Color(0xFF26A69A),
      ),
      const _DashCard(
        icon: Icons.live_tv_outlined,
        title: 'Streams',
        value: '—',
        growth: '+0%',
        positive: true,
        color: Color(0xFFE53935),
      ),
      const _DashCard(
        icon: Icons.flag_outlined,
        title: 'Reports',
        value: '—',
        growth: '0',
        positive: null,
        color: Color(0xFFFB8C00),
      ),
      const _DashCard(
        icon: Icons.insights_outlined,
        title: 'Analytics',
        value: '—',
        growth: '+0%',
        positive: true,
        color: AdminColors.primaryBlueLight,
      ),
    ];

    if (type == AdminAppType.superAdmin) {
      base.add(
        const _DashCard(
          icon: Icons.payments_outlined,
          title: 'Revenue',
          value: '—',
          growth: '+0%',
          positive: true,
          color: Color(0xFF43A047),
        ),
      );
    }

    return base;
  }
}

class _DashCard {
  const _DashCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.growth,
    required this.positive,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String growth;
  final bool? positive;
  final Color color;
}

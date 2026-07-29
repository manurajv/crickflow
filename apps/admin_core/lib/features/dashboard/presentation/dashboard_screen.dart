import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_empty_state.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/dashboard_models.dart';
import '../providers/dashboard_providers.dart';
import 'widgets/dashboard_activity_health.dart';
import 'widgets/dashboard_quick_overview.dart';
import 'widgets/dashboard_recent_sections.dart';
import 'widgets/dashboard_section_header.dart';
import 'widgets/dashboard_welcome_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = ['Dashboard'];
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(dashboardControllerProvider.notifier).refresh(quiet: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dashboardControllerProvider);

    return PermissionGate(
      permission: AdminPermission.canViewDashboard,
      child: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const _DashboardSkeleton(),
        error: (error, _) => Center(
          child: CfEmptyState(
            icon: Icons.error_outline,
            title: 'Couldn’t load dashboard',
            message: error.toString(),
            action: CfButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () =>
                  ref.read(dashboardControllerProvider.notifier).refresh(),
            ),
          ),
        ),
        data: (snapshot) => _DashboardBody(
          snapshot: snapshot,
          refreshing: _refreshing,
          onRefresh: _refresh,
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.snapshot,
    required this.onRefresh,
    required this.refreshing,
  });

  final DashboardSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final overviewCols = width >= 1400
            ? 4
            : width >= 1100
                ? 3
                : width >= 720
                    ? 2
                    : 1;
        final twoCol = width >= 1100;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              width >= 1400 ? 28 : 20,
              20,
              width >= 1400 ? 28 : 20,
              32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardWelcomeHeader(
                  scopeLabel: snapshot.scopeLabel,
                  isOrganizationScoped: snapshot.isOrganizationScoped,
                  onRefresh: () {
                    onRefresh();
                  },
                  refreshing: refreshing,
                ),
                const SizedBox(height: 22),
                DashboardQuickActionsSection(actions: snapshot.quickActions),
                const SizedBox(height: 26),
                DashboardOverviewSection(
                  metrics: snapshot.overview,
                  crossAxisCount: overviewCols,
                ),
                const SizedBox(height: 26),
                if (twoCol)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: DashboardLiveActivitySection(
                          items: snapshot.activity,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: DashboardPlatformHealthSection(
                          items: snapshot.platformHealth,
                        ),
                      ),
                    ],
                  )
                else ...[
                  DashboardLiveActivitySection(items: snapshot.activity),
                  const SizedBox(height: 26),
                  DashboardPlatformHealthSection(
                    items: snapshot.platformHealth,
                  ),
                ],
                const SizedBox(height: 26),
                DashboardSystemStatusSection(items: snapshot.systemStatus),
                const SizedBox(height: 26),
                if (twoCol)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DashboardRecentMatchesSection(
                          items: snapshot.recentMatches,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DashboardRecentReportsSection(
                          items: snapshot.recentReports,
                        ),
                      ),
                    ],
                  )
                else ...[
                  DashboardRecentMatchesSection(items: snapshot.recentMatches),
                  const SizedBox(height: 26),
                  DashboardRecentReportsSection(items: snapshot.recentReports),
                ],
                const SizedBox(height: 26),
                if (twoCol)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DashboardRecentUsersSection(
                          items: snapshot.recentUsers,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DashboardRecentTournamentsSection(
                          items: snapshot.recentTournaments,
                        ),
                      ),
                    ],
                  )
                else ...[
                  DashboardRecentUsersSection(items: snapshot.recentUsers),
                  const SizedBox(height: 26),
                  DashboardRecentTournamentsSection(
                    items: snapshot.recentTournaments,
                  ),
                ],
                const SizedBox(height: 26),
                DashboardAnalyticsPlaceholdersSection(
                  items: snapshot.analyticsPlaceholders,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.all(24),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSkeletonBox(width: 220, height: 28),
                SizedBox(height: 12),
                DashboardSkeletonBox(width: 360, height: 16),
                SizedBox(height: 8),
                DashboardSkeletonBox(width: 280, height: 16),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const DashboardSkeletonBox(width: 140, height: 20),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const SizedBox(
                width: 180,
                child: DashboardSkeletonCard(height: 64),
              ),
            ),
          ),
          const SizedBox(height: 26),
          const DashboardSkeletonBox(width: 120, height: 20),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1100
                  ? 4
                  : constraints.maxWidth >= 720
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (_, _) => const DashboardSkeletonCard(height: 140),
              );
            },
          ),
        ],
      ),
    );
  }
}

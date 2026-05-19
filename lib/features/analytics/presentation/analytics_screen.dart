import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        children: [
          matchesAsync.when(
            data: (matches) => _statCard(
              context,
              'Total Matches',
              '${matches.length}',
              Icons.sports_cricket,
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          teamsAsync.when(
            data: (teams) => _statCard(
              context,
              'Teams',
              '${teams.length}',
              Icons.groups,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            'Location-based analytics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Filter by country, state, and city across users, teams, players, matches, and tournaments. Full filtering UI ships in Phase 2.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance Tracking',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    'Player and team stats update automatically after each completed match via Firebase Cloud Functions.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.gold, size: AppDimens.iconLg),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primaryBlueLight,
              ),
        ),
      ),
    );
  }
}

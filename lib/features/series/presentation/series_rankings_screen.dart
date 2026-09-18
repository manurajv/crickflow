import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_ui.dart';

class SeriesRankingsScreen extends ConsumerWidget {
  const SeriesRankingsScreen({super.key, required this.seriesId});
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: const CfChromeAppBar(
        title: Text('Series rankings'),
        bottom: TabBar(
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          tabs: [
            Tab(text: 'Clubs'),
            Tab(text: 'Players'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          ref
              .watch(seriesClubRankingsProvider(seriesId))
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (rows) => rows.isEmpty
                    ? const SeriesEmptyState(
                        icon: Icons.leaderboard_outlined,
                        title: 'No club rankings yet',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppDimens.spaceMd),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) => ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(rows[i].clubName),
                          subtitle: Text(
                            'P ${rows[i].played} · W ${rows[i].won} · '
                            'NRR ${rows[i].netRunRate.toStringAsFixed(3)}',
                          ),
                          trailing: Text(
                            '${rows[i].points} pts',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
          ref
              .watch(seriesPlayerRankingsProvider(seriesId))
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (rows) => rows.isEmpty
                    ? const SeriesEmptyState(
                        icon: Icons.sports_cricket_outlined,
                        title: 'No player rankings yet',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppDimens.spaceMd),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) => ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(rows[i].displayName),
                          subtitle: Text(
                            '${rows[i].matches} matches · ${rows[i].wickets} wickets',
                          ),
                          trailing: Text(
                            '${rows[i].runs} runs',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
        ],
      ),
    ),
  );
}

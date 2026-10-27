import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'tabs/org_leaderboard_tab.dart';

/// Full-screen org leaderboard (points table + player rankings).
class SeriesRankingsScreen extends ConsumerWidget {
  const SeriesRankingsScreen({super.key, required this.seriesId});
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(seriesByIdProvider(seriesId));
    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Leaderboard')),
      body: series.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (item) => item == null
            ? const Center(child: Text('Organization not found'))
            : OrgLeaderboardTab(seriesId: seriesId, series: item),
      ),
    );
  }
}

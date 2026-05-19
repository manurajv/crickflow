import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../../shared/widgets/location_filter_bar.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _filterCountry = '';
  String _filterCity = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null && !profile.location.isEmpty) {
        setState(() {
          _filterCountry = profile.location.country;
          _filterCity = profile.location.city;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final tournamentsAsync = ref.watch(tournamentsProvider);

    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Analytics')),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          Text(
            'Ecosystem overview',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          LocationFilterBar(
            initialCountry: _filterCountry,
            initialCity: _filterCity,
            onFilterChanged: (country, city) {
              setState(() {
                _filterCountry = country;
                _filterCity = city;
              });
            },
          ),
          const SizedBox(height: AppDimens.spaceMd),
          matchesAsync.when(
            data: (all) {
              final matches = _filter(all);
              final live = matches
                  .where((m) =>
                      m.status == MatchStatus.live ||
                      m.status == MatchStatus.inningsBreak)
                  .length;
              final completed = matches
                  .where((m) => m.status == MatchStatus.completed)
                  .length;
              return Column(
                children: [
                  _statRow(context, 'Matches (filtered)', '${matches.length}',
                      Icons.sports_cricket),
                  _statRow(context, 'Live now', '$live', Icons.sensors,
                      color: AppColors.liveIndicator),
                  _statRow(
                      context, 'Completed', '$completed', Icons.check_circle),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          teamsAsync.when(
            data: (all) {
              final teams = all
                  .where((t) => locationMatchesFilter(
                        t.location,
                        _filterCountry,
                        _filterCity,
                      ))
                  .toList();
              return _statRow(
                  context, 'Teams', '${teams.length}', Icons.groups);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          tournamentsAsync.when(
            data: (all) {
              final list = all
                  .where((t) => locationMatchesFilter(
                        t.location,
                        _filterCountry,
                        _filterCity,
                      ))
                  .toList();
              return _statRow(context, 'Tournaments', '${list.length}',
                  Icons.emoji_events_outlined);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Card(
            child: Padding(
              padding: AppDimens.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How stats update',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    'Player and team career stats refresh when a match is marked completed. '
                    'Fantasy points update on every ball via Cloud Functions.',
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

  List<MatchModel> _filter(List<MatchModel> all) {
    return all
        .where((m) => locationMatchesFilter(
              m.location,
              _filterCountry,
              _filterCity,
            ))
        .toList();
  }

  Widget _statRow(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color ?? AppColors.gold, size: AppDimens.iconLg),
        title: Text(title),
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

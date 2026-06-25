import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../domain/scoring/match_lifecycle.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import '../../../shared/widgets/match_list_card.dart';
import '../../community/community_post_ui.dart';

/// Location-aware discovery: matches, tournaments, teams, recruitment.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  static const _categories = [
    (Icons.scoreboard_outlined, 'Scorers'),
    (Icons.sports, 'Umpires'),
    (Icons.mic_outlined, 'Commentators'),
    (Icons.videocam_outlined, 'Streamers'),
    (Icons.emoji_events_outlined, 'Tournaments'),
    (Icons.stadium_outlined, 'Grounds'),
    (Icons.school_outlined, 'Academies'),
    (Icons.person_search_outlined, 'Players'),
  ];

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _filterCountry = '';
  String _filterCity = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedFromProfile());
  }

  void _seedFromProfile() {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null || profile.location.isEmpty) return;
    setState(() {
      _filterCountry = profile.location.country;
      _filterCity = profile.location.city;
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);
    final tournamentsAsync = ref.watch(tournamentsProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return ShellTabScaffold(
      title: const Text('Discover'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              0,
            ),
            child: Text(
              'Cricket near you',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
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
          _sectionTitle(context, 'Live & upcoming matches'),
          matchesAsync.when(
            data: (all) {
              final matches = _filterMatches(all);
              final live = matches
                  .where(MatchLifecycle.isEffectivelyLive)
                  .take(5)
                  .toList();
              final upcoming = matches
                  .where((m) =>
                      m.status == MatchStatus.scheduled ||
                      m.status == MatchStatus.draft)
                  .take(5)
                  .toList();
              final shown = [...live, ...upcoming].take(6).toList();

              if (shown.isEmpty) {
                return _emptyHint(
                  context,
                  'No matches in this area yet. Create one from Home.',
                );
              }
              return Column(
                children: shown
                    .map((m) => MatchListCard(match: m))
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _emptyHint(context, '$e'),
          ),
          _sectionTitle(context, 'Tournaments'),
          tournamentsAsync.when(
            data: (all) {
              final list = all
                  .where((t) => locationMatchesFilter(
                        t.location,
                        _filterCountry,
                        _filterCity,
                      ))
                  .take(5)
                  .toList();
              if (list.isEmpty) {
                return _emptyHint(context, 'No tournaments match this filter.');
              }
              return Column(
                children: list
                    .map(
                      (t) => ListTile(
                        leading: const Icon(Icons.emoji_events_outlined),
                        title: Text(t.name),
                        subtitle: Text(t.location.displayLabel),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/tournaments/${t.id}'),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          _sectionTitle(context, 'Teams nearby'),
          teamsAsync.when(
            data: (all) {
              final list = all
                  .where((t) => locationMatchesFilter(
                        t.location,
                        _filterCountry,
                        _filterCity,
                      ))
                  .take(5)
                  .toList();
              if (list.isEmpty) {
                return _emptyHint(context, 'No teams in this filter.');
              }
              return Column(
                children: list
                    .map(
                      (t) => ListTile(
                        leading: const Icon(Icons.groups),
                        title: Text(t.name),
                        subtitle: Text(
                          '${t.playerIds.length} players · ${t.location.displayLabel}',
                        ),
                        onTap: () => context.push('/teams/${t.id}'),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          _sectionTitle(context, 'Find people & services'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppDimens.spaceSm,
              crossAxisSpacing: AppDimens.spaceSm,
              childAspectRatio: 1.35,
              children: DiscoverScreen._categories.map((c) {
                return Card(
                  child: InkWell(
                    onTap: () {
                      final category = categoryFromDiscoverLabel(c.$2);
                      if (category != null) {
                        context.go('/community?category=${category.name}');
                      } else {
                        context.go('/community');
                      }
                    },
                    borderRadius: AppDimens.cardRadius,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(c.$1,
                            color: AppColors.primaryBlueLight, size: 28),
                        const SizedBox(height: AppDimens.spaceSm),
                        Text(
                          c.$2,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: AppDimens.listPadding,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/players'),
              icon: const Icon(Icons.person),
              label: const Text('All players'),
            ),
          ),
        ],
      ),
    );
  }

  List<MatchModel> _filterMatches(List<MatchModel> all) {
    return all
        .where((m) => locationMatchesFilter(
              m.location,
              _filterCountry,
              _filterCity,
            ))
        .toList();
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _emptyHint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

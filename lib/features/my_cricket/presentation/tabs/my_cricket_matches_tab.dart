import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/player_model.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/location_filter_bar.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../../my_cricket_filters.dart';

class MyCricketMatchesTab extends ConsumerStatefulWidget {
  const MyCricketMatchesTab({super.key});

  @override
  ConsumerState<MyCricketMatchesTab> createState() =>
      _MyCricketMatchesTabState();
}

class _MyCricketMatchesTabState extends ConsumerState<MyCricketMatchesTab> {
  MyCricketListScope _scope = MyCricketListScope.yours;
  String _country = '';
  String _city = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null && !profile.location.isEmpty) {
        setState(() {
          _country = profile.location.country;
          _city = profile.location.city;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);
    final search = ref.watch(myCricketSearchProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final player = ref.watch(myPlayerProvider).valueOrNull;
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();
    final canCreate = canCreateMatches(
      ref.watch(currentUserProfileProvider).valueOrNull?.role ??
          UserRole.organizer,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCreate)
          Material(
            color: AppColors.surfaceElevated,
            child: ListTile(
              dense: true,
              title: const Text('Want to start a match?'),
              trailing: FilledButton(
                onPressed: () => context.push('/match/create'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        _scopeChips(),
        LocationFilterBar(
          initialCountry: _country,
          initialCity: _city,
          onFilterChanged: (c, city) => setState(() {
            _country = c;
            _city = city;
          }),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(matchesProvider),
            child: matchesAsync.when(
              data: (matches) {
                var list = _filter(
                  matches,
                  uid: uid,
                  player: player,
                  userTeamIds: userTeamIds,
                );
                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  list = list
                      .where(
                        (m) =>
                            m.title.toLowerCase().contains(q) ||
                            m.teamAName.toLowerCase().contains(q) ||
                            m.teamBName.toLowerCase().contains(q),
                      )
                      .toList();
                }
                if (list.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 48),
                      Center(child: Text('No matches in this filter')),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => MatchListCard(match: list[i]),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scopeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          _scopeChip('Your', MyCricketListScope.yours),
          const SizedBox(width: AppDimens.spaceXs),
          _scopeChip('Played', MyCricketListScope.played),
          const SizedBox(width: AppDimens.spaceXs),
          _scopeChip('All', MyCricketListScope.all),
        ],
      ),
    );
  }

  List<MatchModel> _filter(
    List<MatchModel> matches, {
    String? uid,
    PlayerModel? player,
    required Set<String> userTeamIds,
  }) {
    return matches.where((m) {
      if (!locationMatchesFilter(m.location, _country, _city)) return false;
      return filterMatchByScope(
        m,
        _scope,
        uid: uid,
        player: player,
        userTeamIds: userTeamIds,
      );
    }).toList();
  }

  Widget _scopeChip(String label, MyCricketListScope scope) {
    final selected = _scope == scope;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _scope = scope),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.35),
      checkmarkColor: AppColors.gold,
      labelStyle: TextStyle(
        color: selected ? AppColors.gold : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/location_filter_bar.dart';
import '../../../../shared/widgets/match_list_card.dart';

enum _MatchScope { yours, live, played, all }

class MyCricketMatchesTab extends ConsumerStatefulWidget {
  const MyCricketMatchesTab({super.key});

  @override
  ConsumerState<MyCricketMatchesTab> createState() =>
      _MyCricketMatchesTabState();
}

class _MyCricketMatchesTabState extends ConsumerState<MyCricketMatchesTab> {
  _MatchScope _scope = _MatchScope.yours;
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: Row(
            children: [
              _scopeChip('Your', _MatchScope.yours),
              const SizedBox(width: AppDimens.spaceXs),
              _scopeChip('Live', _MatchScope.live),
              const SizedBox(width: AppDimens.spaceXs),
              _scopeChip('Played', _MatchScope.played),
              const SizedBox(width: AppDimens.spaceXs),
              _scopeChip('All', _MatchScope.all),
            ],
          ),
        ),
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
                var list = _filter(matches, uid);
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

  List<MatchModel> _filter(List<MatchModel> matches, String? uid) {
    return matches.where((m) {
      if (!locationMatchesFilter(m.location, _country, _city)) return false;
      switch (_scope) {
        case _MatchScope.live:
          return m.status == MatchStatus.live ||
              m.status == MatchStatus.inningsBreak;
        case _MatchScope.played:
          return m.status == MatchStatus.completed;
        case _MatchScope.yours:
          return uid != null &&
              (m.createdBy == uid || m.scorerIds.contains(uid));
        case _MatchScope.all:
          return true;
      }
    }).toList();
  }

  Widget _scopeChip(String label, _MatchScope scope) {
    final selected = _scope == scope;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _scope = scope),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.35),
      checkmarkColor: AppColors.gold,
    );
  }
}

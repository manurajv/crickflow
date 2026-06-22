import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/match_model.dart';
import '../../../../domain/services/profile_match_filter_service.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../widgets/profile_match_filter_button.dart';

class ProfileMatchesTab extends ConsumerWidget {
  const ProfileMatchesTab({
    super.key,
    required this.matches,
  });

  final List<MatchModel> matches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(profileMatchFiltersProvider);
    final list = filterProfileMatches(matches, filters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileMatchFilterButton(matches: matches),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myCricketProfileProvider);
              ref.invalidate(matchesProvider);
            },
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      MatchListEmptyState(
                        message: 'No matches match your filters',
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => MatchListCard(match: list[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

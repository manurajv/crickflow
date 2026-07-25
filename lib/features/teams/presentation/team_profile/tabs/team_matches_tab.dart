import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/team_players_provider.dart';
import '../../../../../shared/providers/team_profile_provider.dart';
import '../../../../../shared/widgets/match_list_card.dart';
import '../widgets/team_profile_empty_state.dart';

class TeamMatchesTab extends ConsumerWidget {
  const TeamMatchesTab({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(teamProfileFilteredMatchesProvider(teamId));
    final filters = ref.watch(teamProfileMatchFiltersProvider);

    return matchesAsync.when(
      loading: () => const TeamProfileSkeleton(),
      error: (e, _) => TeamProfileEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load matches',
        subtitle: '$e',
      ),
      data: (matches) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(matchesProvider);
            ref.invalidate(teamByIdProvider(teamId));
            ref.invalidate(teamPlayersProvider(teamId));
          },
          child: matches.isEmpty
              ? TeamProfileEmptyState(
                  icon: Icons.sports_cricket_outlined,
                  title: filters.hasActiveFilters
                      ? 'No matches match your filters'
                      : 'No matches yet',
                  subtitle: filters.hasActiveFilters
                      ? 'Try clearing or changing filters in the app bar.'
                      : 'Matches played by this team will appear here.',
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: matches.length,
                  itemBuilder: (_, i) => MatchListCard(match: matches[i]),
                ),
        );
      },
    );
  }
}

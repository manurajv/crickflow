import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/match_mvp_models.dart';

class MvpFilterChips extends StatelessWidget {
  const MvpFilterChips({
    super.key,
    required this.selected,
    required this.teamAName,
    required this.teamBName,
    required this.onSelected,
    required this.cf,
  });

  final MvpLeaderboardFilter selected;
  final String teamAName;
  final String teamBName;
  final ValueChanged<MvpLeaderboardFilter> onSelected;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final filters = <MvpLeaderboardFilter, String>{
      MvpLeaderboardFilter.all: 'All',
      MvpLeaderboardFilter.batters: 'Batters',
      MvpLeaderboardFilter.bowlers: 'Bowlers',
      MvpLeaderboardFilter.fielders: 'Fielders',
      MvpLeaderboardFilter.teamA:
          teamAName.isNotEmpty ? teamAName : 'Team A',
      MvpLeaderboardFilter.teamB:
          teamBName.isNotEmpty ? teamBName : 'Team B',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final isSelected = selected == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: AppDimens.spaceXs),
            child: FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(entry.key),
              selectedColor: cf.accent.withValues(alpha: 0.14),
              backgroundColor: cf.sectionBackground,
              labelStyle: TextStyle(
                color: isSelected ? cf.accent : cf.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? cf.accent : cf.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

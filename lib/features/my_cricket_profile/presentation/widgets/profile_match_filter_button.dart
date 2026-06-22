import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/match_model.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../domain/services/profile_match_filter_service.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../profile_match_filters_screen.dart';

class ProfileMatchFilterButton extends ConsumerWidget {
  const ProfileMatchFilterButton({
    super.key,
    required this.matches,
    this.compact = false,
  });

  final List<MatchModel> matches;
  final bool compact;

  void _clearFilters(WidgetRef ref) {
    ref.read(profileMatchFiltersProvider.notifier).state =
        const ProfileMatchFilters();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final filters = ref.watch(profileMatchFiltersProvider);
    final options = ProfileMatchFilterOptions.fromMatches(matches);
    final activeCount = filters.activeFilterCount;

    final filterButton = OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileMatchFiltersScreen(options: options),
          ),
        );
      },
      icon: Badge(
        isLabelVisible: activeCount > 0,
        label: Text('$activeCount'),
        backgroundColor: cf.accent,
        child: Icon(Icons.filter_list, size: compact ? 18 : 20),
      ),
      label: Text(activeCount > 0 ? 'Filters ($activeCount)' : 'Filters'),
      style: OutlinedButton.styleFrom(
        foregroundColor: cf.textPrimary,
        side: BorderSide(color: cf.border),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppDimens.spaceSm : AppDimens.spaceMd,
          vertical: compact ? 6 : AppDimens.spaceSm,
        ),
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
      ),
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        filterButton,
        if (filters.hasActiveFilters) ...[
          const SizedBox(width: AppDimens.spaceXs),
          TextButton(
            onPressed: () => _clearFilters(ref),
            style: TextButton.styleFrom(
              visualDensity:
                  compact ? VisualDensity.compact : VisualDensity.standard,
              tapTargetSize:
                  compact ? MaterialTapTargetSize.shrinkWrap : null,
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm)
                  : null,
            ),
            child: const Text('Clear'),
          ),
        ],
      ],
    );

    if (compact) return controls;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: controls,
      ),
    );
  }
}

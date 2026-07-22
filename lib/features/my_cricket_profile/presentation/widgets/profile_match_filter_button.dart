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
    this.iconOnly = false,
    this.iconColor,
  });

  final List<MatchModel> matches;
  final bool compact;

  /// App-bar style: icon (+ badge) only, optional clear as a second icon.
  final bool iconOnly;
  final Color? iconColor;

  void _openFilters(BuildContext context, WidgetRef ref) {
    final options = ProfileMatchFilterOptions.fromMatches(matches);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileMatchFiltersScreen(options: options),
      ),
    );
  }

  void _clearFilters(WidgetRef ref) {
    ref.read(profileMatchFiltersProvider.notifier).state =
        const ProfileMatchFilters();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final filters = ref.watch(profileMatchFiltersProvider);
    final activeCount = filters.activeFilterCount;
    final color = iconColor ?? cf.textPrimary;

    if (iconOnly) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: activeCount > 0 ? 'Filters ($activeCount)' : 'Filters',
            onPressed: () => _openFilters(context, ref),
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              backgroundColor: cf.accent,
              child: Icon(Icons.filter_list, color: color),
            ),
          ),
          if (filters.hasActiveFilters)
            IconButton(
              tooltip: 'Clear filters',
              onPressed: () => _clearFilters(ref),
              icon: Icon(Icons.filter_list_off, color: color),
            ),
        ],
      );
    }

    final filterButton = OutlinedButton.icon(
      onPressed: () => _openFilters(context, ref),
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

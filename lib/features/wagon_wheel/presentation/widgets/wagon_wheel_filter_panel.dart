import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_filter_options.dart';

/// Which filters are locked because they were set when opening full view.
class WagonWheelLockedFilters {
  const WagonWheelLockedFilters({
    this.batter = false,
    this.bowler = false,
    this.team = false,
    this.match = false,
    this.tournament = false,
  });

  final bool batter;
  final bool bowler;
  final bool team;
  final bool match;
  final bool tournament;

  factory WagonWheelLockedFilters.fromInitial(WagonWheelFilter initial) {
    return WagonWheelLockedFilters(
      batter: initial.batterId != null,
      bowler: initial.bowlerId != null,
      team: initial.teamId != null,
      match: initial.matchId != null,
      tournament: initial.tournamentId != null,
    );
  }
}

/// Full and compact filter controls for wagon wheel analytics.
class WagonWheelFilterPanel extends StatelessWidget {
  const WagonWheelFilterPanel({
    super.key,
    required this.filter,
    required this.options,
    required this.onChanged,
    this.locked = const WagonWheelLockedFilters(),
    this.compact = false,
    this.showViewMode = true,
    this.onReset,
  });

  final WagonWheelFilter filter;
  final WagonWheelFilterOptions options;
  final ValueChanged<WagonWheelFilter> onChanged;
  final WagonWheelLockedFilters locked;
  final bool compact;
  final bool showViewMode;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Row(
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (onReset != null)
                TextButton(
                  onPressed: onReset,
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
        ],
        if (!locked.batter && options.batters.isNotEmpty)
          _dropdown(
            context,
            label: 'Batter',
            value: filter.batterId,
            items: options.batters,
            onSelected: (id) => onChanged(
              id == null
                  ? filter.copyWith(clearBatterId: true)
                  : filter.copyWith(batterId: id),
            ),
          ),
        if (!locked.bowler && options.bowlers.isNotEmpty)
          _dropdown(
            context,
            label: 'Bowler',
            value: filter.bowlerId,
            items: options.bowlers,
            onSelected: (id) => onChanged(
              id == null
                  ? filter.copyWith(clearBowlerId: true)
                  : filter.copyWith(bowlerId: id),
            ),
          ),
        if (!locked.team && options.teams.isNotEmpty)
          _dropdown(
            context,
            label: 'Team',
            value: filter.teamId,
            items: options.teams,
            onSelected: (id) => onChanged(
              id == null
                  ? filter.copyWith(clearTeamId: true)
                  : filter.copyWith(teamId: id),
            ),
          ),
        if (options.inningsNumbers.length > 1) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Text('Innings', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _inningsChip(context, label: 'All', innings: null),
                ...options.inningsNumbers.map(
                  (n) => _inningsChip(
                    context,
                    label: _inningsLabel(n),
                    innings: n,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppDimens.spaceSm),
        Text('Runs', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: WagonWheelRunFilter.values.map((f) {
              final selected = filter.runFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(f.label, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  onSelected: (_) => onChanged(filter.copyWith(runFilter: f)),
                  selectedColor: AppColors.gold.withValues(alpha: 0.3),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        if (!compact && options.minDate != null && options.maxDate != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  context,
                  label: 'From',
                  date: filter.fromDate,
                  onPick: (d) => onChanged(filter.copyWith(fromDate: d)),
                  onClear: () => onChanged(filter.copyWith(clearFromDate: true)),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _dateButton(
                  context,
                  label: 'To',
                  date: filter.toDate,
                  onPick: (d) => onChanged(filter.copyWith(toDate: d)),
                  onClear: () => onChanged(filter.copyWith(clearToDate: true)),
                ),
              ),
            ],
          ),
        ],
        if (showViewMode) ...[
          const SizedBox(height: AppDimens.spaceSm),
          SegmentedButton<WagonWheelViewMode>(
            segments: const [
              ButtonSegment(
                value: WagonWheelViewMode.lines,
                label: Text('Lines', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: WagonWheelViewMode.scatter,
                label: Text('Scatter', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: WagonWheelViewMode.heatmap,
                label: Text('Heat', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {filter.viewMode},
            onSelectionChanged: (s) =>
                onChanged(filter.copyWith(viewMode: s.first)),
          ),
        ],
      ],
    );
  }

  Widget _inningsChip(
    BuildContext context, {
    required String label,
    required int? innings,
  }) {
    final selected = filter.inningsNumber == innings ||
        (innings == null && filter.inningsNumber == null);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => onChanged(
          innings == null
              ? filter.copyWith(clearInnings: true)
              : filter.copyWith(inningsNumber: innings),
        ),
        selectedColor: AppColors.gold.withValues(alpha: 0.3),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _inningsLabel(int n) => switch (n) {
        1 => '1st inn',
        2 => '2nd inn',
        _ => 'Inn $n',
      };

  Widget _dropdown(
    BuildContext context, {
    required String label,
    required String? value,
    required List<WagonWheelFilterOption> items,
    required ValueChanged<String?> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All', style: TextStyle(fontSize: 13)),
          ),
          ...items.map(
            (o) => DropdownMenuItem<String?>(
              value: o.id,
              child: Text(o.label, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
        onChanged: onSelected,
      ),
    );
  }

  Widget _dateButton(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime> onPick,
    required VoidCallback onClear,
  }) {
    final fmt = DateFormat('d MMM yy');
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onPick(picked);
      },
      onLongPress: date != null ? onClear : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      child: Text(
        date != null ? '$label: ${fmt.format(date)}' : label,
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

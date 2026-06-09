import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_navigation.dart';
import '../../../../shared/providers/wagon_wheel_filter_options_provider.dart';
import '../../../../shared/providers/wagon_wheel_provider.dart';
import 'wagon_wheel_chart.dart';
import 'wagon_wheel_run_legend.dart';

/// Compact wagon wheel block with quick filters and full-view entry.
class WagonWheelEmbeddedSection extends ConsumerStatefulWidget {
  const WagonWheelEmbeddedSection({
    super.key,
    required this.title,
    required this.baseFilter,
    required this.fullViewTitle,
    this.height = 220,
    this.showWhenEmpty = true,
  });

  final String title;
  final WagonWheelFilter baseFilter;
  final String fullViewTitle;
  final double height;
  final bool showWhenEmpty;

  @override
  ConsumerState<WagonWheelEmbeddedSection> createState() =>
      _WagonWheelEmbeddedSectionState();
}

class _WagonWheelEmbeddedSectionState
    extends ConsumerState<WagonWheelEmbeddedSection> {
  late WagonWheelFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.baseFilter;
  }

  @override
  void didUpdateWidget(covariant WagonWheelEmbeddedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseFilter != widget.baseFilter) {
      _filter = widget.baseFilter.copyWith(
        runFilter: _filter.runFilter,
        inningsNumber: _filter.inningsNumber,
        viewMode: _filter.viewMode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(wagonWheelAnalyticsProvider(_filter));
    final options = ref.watch(
      wagonWheelFilterOptionsProvider(
        WagonWheelOptionsScope(
          matchId: widget.baseFilter.matchId,
          tournamentId: widget.baseFilter.tournamentId,
          batterId: widget.baseFilter.batterId,
          teamId: widget.baseFilter.teamId,
        ),
      ),
    );

    if (!widget.showWhenEmpty && data.shots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => context.push(
                WagonWheelNavigation.path(
                  filter: _filter,
                  title: widget.fullViewTitle,
                ),
              ),
              child: const Text('Full view'),
            ),
          ],
        ),
        if (options.inningsNumbers.length > 1 ||
            data.shots.isNotEmpty) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (options.inningsNumbers.length > 1) ...[
                  _quickChip('All inn', _filter.inningsNumber == null, () {
                    setState(
                      () => _filter = _filter.copyWith(clearInnings: true),
                    );
                  }),
                  ...options.inningsNumbers.map((n) {
                    return _quickChip(
                      n == 1 ? '1st' : n == 2 ? '2nd' : 'Inn $n',
                      _filter.inningsNumber == n,
                      () => setState(
                        () => _filter = _filter.copyWith(inningsNumber: n),
                      ),
                    );
                  }),
                ],
                _quickChip(
                  '4s & 6s',
                  _filter.runFilter == WagonWheelRunFilter.boundaries,
                  () => setState(() {
                    _filter = _filter.copyWith(
                      runFilter: _filter.runFilter ==
                              WagonWheelRunFilter.boundaries
                          ? WagonWheelRunFilter.all
                          : WagonWheelRunFilter.boundaries,
                    );
                  }),
                ),
                _quickChip(
                  'Sixes',
                  _filter.runFilter == WagonWheelRunFilter.sixes,
                  () => setState(() {
                    _filter = _filter.copyWith(
                      runFilter: _filter.runFilter == WagonWheelRunFilter.sixes
                          ? WagonWheelRunFilter.all
                          : WagonWheelRunFilter.sixes,
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppDimens.spaceSm),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: AppDimens.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WagonWheelChart(
                  shots: data.shots,
                  viewMode: _filter.viewMode,
                  insights: data.insights,
                  height: widget.height,
                  compact: true,
                ),
                if (data.shots.isNotEmpty) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  const WagonWheelRunLegend(compact: true),
                ],
              ],
            ),
          ),
        ),
        if (data.shots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${data.shots.length} shot${data.shots.length == 1 ? '' : 's'} · '
              'Off ${data.insights.offSidePercent.toStringAsFixed(0)}% · '
              'Leg ${data.insights.legSidePercent.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _quickChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 10)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.gold.withValues(alpha: 0.3),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

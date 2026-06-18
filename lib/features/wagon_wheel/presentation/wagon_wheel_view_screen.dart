import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import '../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../domain/wagon_wheel/wagon_wheel_filter_options.dart';
import '../../../shared/providers/wagon_wheel_filter_options_provider.dart';
import '../../../shared/providers/wagon_wheel_provider.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/wagon_wheel_chart.dart';
import 'widgets/wagon_wheel_filter_panel.dart';
import 'widgets/wagon_wheel_run_legend.dart';

/// Full wagon wheel analytics with comprehensive filters.
class WagonWheelViewScreen extends ConsumerStatefulWidget {
  const WagonWheelViewScreen({
    super.key,
    this.initialFilter = const WagonWheelFilter(),
    this.title = 'Wagon wheel',
  });

  final WagonWheelFilter initialFilter;
  final String title;

  @override
  ConsumerState<WagonWheelViewScreen> createState() =>
      _WagonWheelViewScreenState();
}

class _WagonWheelViewScreenState extends ConsumerState<WagonWheelViewScreen> {
  late WagonWheelFilter _filter;
  late final WagonWheelLockedFilters _locked;
  bool _filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _locked = WagonWheelLockedFilters.fromInitial(widget.initialFilter);
  }

  void _resetFilters() {
    setState(() {
      _filter = WagonWheelFilter(
        batterId: _locked.batter ? widget.initialFilter.batterId : null,
        bowlerId: _locked.bowler ? widget.initialFilter.bowlerId : null,
        teamId: _locked.team ? widget.initialFilter.teamId : null,
        matchId: _locked.match ? widget.initialFilter.matchId : null,
        tournamentId:
            _locked.tournament ? widget.initialFilter.tournamentId : null,
        viewMode: _filter.viewMode,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(wagonWheelAnalyticsProvider(_filter));
    final options = ref.watch(
      wagonWheelFilterOptionsProvider(
        WagonWheelOptionsScope(
          matchId: _filter.matchId ?? widget.initialFilter.matchId,
          tournamentId:
              _filter.tournamentId ?? widget.initialFilter.tournamentId,
          batterId: _filter.batterId ?? widget.initialFilter.batterId,
          teamId: _filter.teamId ?? widget.initialFilter.teamId,
        ),
      ),
    );

    return Scaffold(
      appBar: CfChromeAppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.tune),
            tooltip: _filtersExpanded ? 'Hide filters' : 'Show filters',
            onPressed: () =>
                setState(() => _filtersExpanded = !_filtersExpanded),
          ),
        ],
      ),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          _SummaryHeader(
            shotCount: data.shots.length,
            insights: data.insights,
            activeFilters: _activeFilterLabels(options),
          ),
          if (_filtersExpanded) ...[
            const SizedBox(height: AppDimens.spaceMd),
            WagonWheelFilterPanel(
              filter: _filter,
              options: options,
              locked: _locked,
              onChanged: (f) => setState(() => _filter = f),
              onReset: _resetFilters,
            ),
            const Divider(height: AppDimens.spaceLg),
          ],
          WagonWheelChart(
            shots: data.shots,
            insights: data.insights,
            filter: _filter,
            leftHandedByBatterId: data.leftHandedByBatterId,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          const WagonWheelRunLegend(),
          if (data.insights.totalShots > 0) ...[
            const SizedBox(height: AppDimens.spaceLg),
            Text('Insights', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimens.spaceSm),
            _insightTile(
              context,
              'Total scoring shots',
              '${data.insights.totalShots}',
            ),
            _insightTile(
              context,
              'Off side',
              '${data.insights.offSidePercent.toStringAsFixed(0)}%',
            ),
            _insightTile(
              context,
              'Leg side',
              '${data.insights.legSidePercent.toStringAsFixed(0)}%',
            ),
            if (data.insights.straightPercent > 0)
              _insightTile(
                context,
                'Straight',
                '${data.insights.straightPercent.toStringAsFixed(0)}%',
              ),
            if (data.insights.boundaryCount > 0)
              _insightTile(
                context,
                'Boundaries',
                '${data.insights.boundaryCount} '
                    '(${data.insights.boundaryPercent.toStringAsFixed(0)}%)',
              ),
            if (data.insights.favoriteZone.isNotEmpty)
              _insightTile(
                context,
                'Most common scoring area',
                data.insights.favoriteZone,
              ),
            if (data.insights.mostCommonBoundaryRegion.isNotEmpty)
              _insightTile(
                context,
                'Top boundary region',
                data.insights.mostCommonBoundaryRegion,
              ),
            if (data.insights.strongZones.isNotEmpty)
              _insightTile(
                context,
                'Strong zones',
                data.insights.strongZones.join(', '),
              ),
            if (data.insights.weakZones.isNotEmpty)
              _insightTile(
                context,
                'Weak zones',
                data.insights.weakZones.join(', '),
              ),
          ],
        ],
      ),
    );
  }

  List<String> _activeFilterLabels(WagonWheelFilterOptions options) {
    final labels = <String>[];
    if (_filter.batterId != null) {
      labels.add(_labelFor(options.batters, _filter.batterId!, 'Batter'));
    }
    if (_filter.bowlerId != null) {
      labels.add(_labelFor(options.bowlers, _filter.bowlerId!, 'Bowler'));
    }
    if (_filter.teamId != null) {
      labels.add(_labelFor(options.teams, _filter.teamId!, 'Team'));
    }
    if (_filter.inningsNumber != null) {
      labels.add('Inn ${_filter.inningsNumber}');
    }
    if (_filter.runFilter != WagonWheelRunFilter.all) {
      labels.add(_filter.runFilter.label);
    }
    return labels;
  }

  String _labelFor(
    List<WagonWheelFilterOption> options,
    String id,
    String fallback,
  ) {
    for (final o in options) {
      if (o.id == id) return o.label;
    }
    return fallback;
  }

  Widget _insightTile(BuildContext context, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.shotCount,
    required this.insights,
    required this.activeFilters,
  });

  final int shotCount;
  final WagonWheelInsights insights;
  final List<String> activeFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$shotCount',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shotCount == 1 ? 'shot mapped' : 'shots mapped',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (activeFilters.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: activeFilters
                    .map(
                      (l) => Chip(
                        label: Text(l, style: const TextStyle(fontSize: 10)),
                        backgroundColor: AppColors.surfaceElevated,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

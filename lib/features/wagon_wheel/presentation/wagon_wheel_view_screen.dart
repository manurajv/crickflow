import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../shared/providers/wagon_wheel_provider.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/wagon_wheel_chart.dart';

/// Full wagon wheel analytics with filters.
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

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(wagonWheelAnalyticsProvider(_filter));

    return Scaffold(
      appBar: CfChromeAppBar(title: Text(widget.title)),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: WagonWheelRunFilter.values.map((f) {
                final selected = _filter.runFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.label, style: const TextStyle(fontSize: 11)),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _filter = _filter.copyWith(runFilter: f)),
                    selectedColor: AppColors.gold.withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            ),
          ),
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
            selected: {_filter.viewMode},
            onSelectionChanged: (s) => setState(
              () => _filter = _filter.copyWith(viewMode: s.first),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          WagonWheelChart(
            shots: data.shots,
            viewMode: _filter.viewMode,
            insights: data.insights,
            height: 320,
          ),
          if (data.insights.totalShots > 0) ...[
            const SizedBox(height: AppDimens.spaceLg),
            Text('Insights', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppDimens.spaceSm),
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

  Widget _insightTile(BuildContext context, String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

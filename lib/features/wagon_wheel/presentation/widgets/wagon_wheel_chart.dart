import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_batting_orientation.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import 'wagon_wheel_renderer.dart';

/// Reusable wagon wheel visualization with optional insights footer.
class WagonWheelChart extends StatelessWidget {
  const WagonWheelChart({
    super.key,
    required this.shots,
    this.insights,
    this.filter = const WagonWheelFilter(),
    this.leftHandedByBatterId = const {},
    this.batterBattingStyle,
    this.maxWidth,
    this.compact = false,
  });

  final List<WagonWheelShotPoint> shots;
  final WagonWheelInsights? insights;
  final WagonWheelFilter filter;
  final Map<String, bool> leftHandedByBatterId;
  final String? batterBattingStyle;
  final double? maxWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (shots.isEmpty) {
      return SizedBox(
        height: maxWidth ?? 200,
        child: Center(
          child: Text(
            'No wagon wheel data yet.\nEnable tracking in match settings.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      );
    }

    final batterId = filter.batterId;
    final viewAsLeftHanded = batterId != null &&
        (leftHandedByBatterId[batterId] ??
            WagonWheelBattingOrientation.isLeftHanded(batterBattingStyle));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WagonWheelFieldCanvas(
          shots: shots,
          maxWidth: maxWidth,
          leftHandedByBatterId: leftHandedByBatterId,
          fallbackBatterId: batterId,
          fallbackBattingStyle: batterBattingStyle,
          showSideLabels: WagonWheelBattingOrientation.showSideLabels(filter),
          viewAsLeftHanded: viewAsLeftHanded,
        ),
        if (!compact && insights != null && insights!.totalShots > 0) ...[
          const SizedBox(height: AppDimens.spaceSm),
          _InsightsRow(insights: insights!),
        ],
      ],
    );
  }
}

class _InsightsRow extends StatelessWidget {
  const _InsightsRow({required this.insights});

  final WagonWheelInsights insights;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('${insights.totalShots} shots'),
        if (insights.favoriteZone.isNotEmpty)
          _chip('Fav: ${insights.favoriteZone}'),
        _chip('Off ${insights.offSidePercent.toStringAsFixed(0)}%'),
        _chip('Leg ${insights.legSidePercent.toStringAsFixed(0)}%'),
        if (insights.boundaryCount > 0)
          _chip(
            'Boundaries ${insights.boundaryPercent.toStringAsFixed(0)}%',
          ),
      ],
    );
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: AppColors.surfaceElevated,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}

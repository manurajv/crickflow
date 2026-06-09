import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/wagon_wheel_data.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_colors.dart';

/// Colour key for run types on the wagon wheel chart.
class WagonWheelRunLegend extends StatelessWidget {
  const WagonWheelRunLegend({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = [
      (WagonWheelShotType.single, '1'),
      (WagonWheelShotType.double, '2'),
      (WagonWheelShotType.triple, '3'),
      (WagonWheelShotType.four, '4'),
      (WagonWheelShotType.six, '6'),
    ];

    return Wrap(
      spacing: compact ? 6 : 10,
      runSpacing: 6,
      children: items.map((item) {
        final color = WagonWheelColors.forShotType(item.$1);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 10 : 12,
              height: compact ? 10 : 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.$2,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

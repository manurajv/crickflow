import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/wagon_wheel_data.dart';
import '../../../domain/wagon_wheel/wagon_wheel_colors.dart';
import 'widgets/wagon_wheel_ground_painter.dart';

/// Full-screen wagon wheel capture shown after a valid batting shot.
class WagonWheelSelectionSheet extends StatefulWidget {
  const WagonWheelSelectionSheet({
    super.key,
    required this.batsmanRuns,
  });

  final int batsmanRuns;

  static Future<WagonWheelData?> show(
    BuildContext context, {
    required int batsmanRuns,
  }) {
    return showModalBottomSheet<WagonWheelData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      builder: (_) => WagonWheelSelectionSheet(batsmanRuns: batsmanRuns),
    );
  }

  @override
  State<WagonWheelSelectionSheet> createState() =>
      _WagonWheelSelectionSheetState();
}

class _WagonWheelSelectionSheetState extends State<WagonWheelSelectionSheet> {
  double _markerX = WagonWheelData.pitchCenterX;
  double _markerY = 35;

  void _updateMarker(Offset local, Size size) {
    final pct = percentFromLocal(local, size);
    setState(() {
      _markerX = pct.dx;
      _markerY = pct.dy;
    });
  }

  void _confirm() {
    final shotType = WagonWheelShotType.fromBatsmanRuns(widget.batsmanRuns);
    Navigator.pop(
      context,
      WagonWheelData(
        enabled: true,
        x: _markerX,
        y: _markerY,
        shotType: shotType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shotType = WagonWheelShotType.fromBatsmanRuns(widget.batsmanRuns);
    final color = WagonWheelColors.forShotType(shotType);
    final height = MediaQuery.sizeOf(context).height * 0.88;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wagon wheel',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Tap or drag to mark where the ${widget.batsmanRuns} '
                        'landed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    '${widget.batsmanRuns} run${widget.batsmanRuns == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final groundSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    onTapDown: (d) => _updateMarker(d.localPosition, groundSize),
                    onPanUpdate: (d) =>
                        _updateMarker(d.localPosition, groundSize),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        size: groundSize,
                        painter: WagonWheelSelectionPainter(
                          markerX: _markerX,
                          markerY: _markerY,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size(0, AppDimens.buttonHeightLarge),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size(0, AppDimens.buttonHeightLarge),
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Confirm shot'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

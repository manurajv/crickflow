import 'package:flutter/material.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/wagon_wheel_data.dart';
import '../../../domain/wagon_wheel/wagon_wheel_colors.dart';
import '../../../domain/wagon_wheel/wagon_wheel_coordinate_mapper.dart';
import '../../../domain/wagon_wheel/wagon_wheel_field_geometry.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';
import 'widgets/wagon_wheel_renderer.dart';

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
    final cf = context.cf;
    return showModalBottomSheet<WagonWheelData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: cf.card,
      shape: ScoringUiKit.sheetShape,
      builder: (_) => WagonWheelSelectionSheet(batsmanRuns: batsmanRuns),
    );
  }

  @override
  State<WagonWheelSelectionSheet> createState() =>
      _WagonWheelSelectionSheetState();
}

class _WagonWheelSelectionSheetState extends State<WagonWheelSelectionSheet> {
  late double _markerX;
  late double _markerY;
  bool _wasClamped = false;
  Size _fieldSize = WagonWheelCoordinateMapper.referenceSize;

  @override
  void initState() {
    super.initState();
    final initial = WagonWheelFieldGeometry.defaultMidOffMarker(
      widget.batsmanRuns,
      _fieldSize,
    );
    _markerX = initial.dx;
    _markerY = initial.dy;
  }

  void _updateMarker(Offset local, Size fieldSize) {
    _fieldSize = fieldSize;
    final mapper = WagonWheelCoordinateMapper(fieldSize);
    final raw = widget.batsmanRuns == 6
        ? mapper.pixelToPercentUnclamped(local)
        : mapper.pixelToPercent(local);
    final clamped = WagonWheelFieldGeometry.clampCoordinate(
      raw.dx,
      raw.dy,
      widget.batsmanRuns,
      fieldSize,
    );
    final didClamp = (raw.dx - clamped.dx).abs() > 0.05 ||
        (raw.dy - clamped.dy).abs() > 0.05;

    setState(() {
      _markerX = clamped.dx;
      _markerY = clamped.dy;
      _wasClamped = didClamp;
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
    final cf = context.cf;
    final shotType = WagonWheelShotType.fromBatsmanRuns(widget.batsmanRuns);
    final color = WagonWheelColors.forShotType(shotType);
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final hint = WagonWheelFieldGeometry.hintForRuns(widget.batsmanRuns);

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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: cf.textPrimary,
                            ),
                      ),
                      Text(
                        hint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                      if (_wasClamped)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.batsmanRuns == 6
                                ? 'Sixes must land beyond the boundary.'
                                : widget.batsmanRuns <= 3
                                    ? 'Marker adjusted inside the boundary.'
                                    : 'Marker adjusted to valid area.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: cf.link,
                                  fontSize: 11,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
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
                  final fieldWidth = constraints.maxWidth;
                  final fieldHeight =
                      fieldWidth / WagonWheelFieldGeometry.fieldAspectRatio;
                  final fieldSize = Size(fieldWidth, fieldHeight);
                  return Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) =>
                          _updateMarker(d.localPosition, fieldSize),
                      onPanUpdate: (d) =>
                          _updateMarker(d.localPosition, fieldSize),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: fieldWidth,
                          height: fieldHeight,
                          child: WagonWheelFieldCanvas(
                            markerX: _markerX,
                            markerY: _markerY,
                            accentColor: color,
                            maxWidth: fieldWidth,
                          ),
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
                    style: ScoringUiKit.outlinedButtonStyle(context).copyWith(
                      minimumSize: WidgetStateProperty.all(
                        const Size(0, AppDimens.buttonHeightLarge),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                      minimumSize: WidgetStateProperty.all(
                        const Size(0, AppDimens.buttonHeightLarge),
                      ),
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

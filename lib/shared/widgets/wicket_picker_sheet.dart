import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import 'scoring_ui_kit.dart';

class _WicketOption {
  const _WicketOption(this.type, this.icon, this.label);
  final WicketType type;
  final IconData icon;
  final String label;
}

/// Bottom sheet to pick dismissal type (first two rows + show more).
Future<WicketType?> showWicketPickerSheet(BuildContext context) {
  return ScoringUiKit.showSheet<WicketType>(
    context,
    isScrollControlled: true,
    builder: (ctx) => const _WicketPickerBody(),
  );
}

class _WicketPickerBody extends StatefulWidget {
  const _WicketPickerBody();

  @override
  State<_WicketPickerBody> createState() => _WicketPickerBodyState();
}

class _WicketPickerBodyState extends State<_WicketPickerBody> {
  static const _options = [
    _WicketOption(WicketType.bowled, Icons.sports_baseball, 'Bowled'),
    _WicketOption(WicketType.caught, Icons.back_hand, 'Caught'),
    _WicketOption(WicketType.lbw, Icons.accessibility_new, 'LBW'),
    _WicketOption(WicketType.runOut, Icons.directions_run, 'Run out'),
    _WicketOption(WicketType.stumped, Icons.pan_tool_alt, 'Stumped'),
    _WicketOption(WicketType.hitWicket, Icons.warning_amber, 'Hit wicket'),
    _WicketOption(WicketType.retiredHurt, Icons.healing, 'Retired hurt'),
    _WicketOption(WicketType.retiredOut, Icons.logout, 'Retired out'),
    _WicketOption(
      WicketType.obstructingField,
      Icons.block,
      'Obstructing field',
    ),
    _WicketOption(WicketType.timedOut, Icons.timer_off, 'Timed out'),
    _WicketOption(WicketType.handledBall, Icons.pan_tool, 'Handled ball'),
    _WicketOption(WicketType.hitBallTwice, Icons.repeat, 'Hit ball twice'),
    _WicketOption(WicketType.mankad, Icons.directions_walk, 'Mankad'),
  ];

  static const _crossAxisCount = 4;
  static const _defaultRows = 2;
  static const _defaultVisibleCount = _crossAxisCount * _defaultRows;

  bool _expanded = false;

  bool get _hasMoreOptions => _options.length > _defaultVisibleCount;

  int get _visibleCount =>
      _expanded ? _options.length : _defaultVisibleCount.clamp(0, _options.length);

  @override
  Widget build(BuildContext context) {
    final maxGridHeight = MediaQuery.sizeOf(context).height * 0.55;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScoringSheetHeader(title: 'Select out type'),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxGridHeight),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: _expanded
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _visibleCount,
                  itemBuilder: (context, i) {
                    final opt = _options[i];
                    return ScoringShortcutTile(
                      icon: opt.icon,
                      iconColor: AppColors.accentRed,
                      label: opt.label,
                      onTap: () => Navigator.pop(context, opt.type),
                    );
                  },
                ),
              ),
            ),
            if (_hasMoreOptions)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

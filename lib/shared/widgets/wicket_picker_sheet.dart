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

/// Bottom sheet to pick dismissal type (reference-style grid).
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
  bool _showAll = false;

  static const _primary = [
    _WicketOption(WicketType.bowled, Icons.sports_baseball, 'Bowled'),
    _WicketOption(WicketType.caught, Icons.back_hand, 'Caught'),
    _WicketOption(WicketType.caughtBehind, Icons.person_outline, 'Caught behind'),
    _WicketOption(WicketType.caughtAndBowled, Icons.sports, 'Caught & bowled'),
    _WicketOption(WicketType.runOut, Icons.directions_run, 'Run out'),
    _WicketOption(WicketType.lbw, Icons.accessibility_new, 'LBW'),
    _WicketOption(WicketType.stumped, Icons.pan_tool_alt, 'Stumped'),
    _WicketOption(WicketType.retiredHurt, Icons.healing, 'Retired hurt'),
  ];

  static const _extra = [
    _WicketOption(WicketType.hitWicket, Icons.warning_amber, 'Hit wicket'),
    _WicketOption(WicketType.retiredOut, Icons.logout, 'Retired out'),
    _WicketOption(
      WicketType.obstructingField,
      Icons.block,
      'Obstructing field',
    ),
    _WicketOption(WicketType.timedOut, Icons.timer_off, 'Timed out'),
    _WicketOption(WicketType.handledBall, Icons.pan_tool, 'Handled ball'),
    _WicketOption(WicketType.hitBallTwice, Icons.repeat, 'Hit ball twice'),
  ];

  List<_WicketOption> get _visible => _showAll ? [..._primary, ..._extra] : _primary;

  @override
  Widget build(BuildContext context) {
    final types = _visible;

    final maxGridHeight = MediaQuery.sizeOf(context).height * 0.42;

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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: types.length,
                  itemBuilder: (context, i) {
                    final opt = types[i];
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
            TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(
                _showAll ? 'Show less' : 'Show more',
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

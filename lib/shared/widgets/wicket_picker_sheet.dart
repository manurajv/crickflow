import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import 'scoring_ui_kit.dart';

/// Bottom sheet to pick dismissal type (reference-style grid).
Future<WicketType?> showWicketPickerSheet(BuildContext context) {
  return ScoringUiKit.showSheet<WicketType>(
    context,
    builder: (ctx) {
      final types = [
        _WicketOption(WicketType.bowled, Icons.sports_baseball, 'Bowled'),
        _WicketOption(WicketType.caught, Icons.back_hand, 'Caught'),
        _WicketOption(WicketType.caught, Icons.person_outline, 'Caught behind'),
        _WicketOption(WicketType.caught, Icons.sports, 'Caught & bowled'),
        _WicketOption(WicketType.runOut, Icons.directions_run, 'Run out'),
        _WicketOption(WicketType.lbw, Icons.accessibility_new, 'LBW'),
        _WicketOption(WicketType.stumped, Icons.pan_tool_alt, 'Stumped'),
        _WicketOption(WicketType.retired, Icons.healing, 'Retired hurt'),
      ];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ScoringSheetHeader(title: 'Select out type'),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                      onTap: () => Navigator.pop(ctx, opt.type),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Show more',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _WicketOption {
  const _WicketOption(this.type, this.icon, this.label);
  final WicketType type;
  final IconData icon;
  final String label;
}

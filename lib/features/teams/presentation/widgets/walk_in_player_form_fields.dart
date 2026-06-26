import 'package:flutter/material.dart';

import '../../../../core/constants/player_profile_constants.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';

/// Walk-in / guest player fields — same options as match squad guest form.
class WalkInPlayerFormFields extends StatelessWidget {
  const WalkInPlayerFormFields({
    super.key,
    required this.nameController,
    required this.role,
    required this.battingStyle,
    required this.bowlingStyle,
    required this.onRoleChanged,
    required this.onBattingStyleChanged,
    required this.onBowlingStyleChanged,
  });

  final TextEditingController nameController;
  final PlayerPlayingRole? role;
  final String? battingStyle;
  final PlayerBowlingStyle? bowlingStyle;
  final ValueChanged<PlayerPlayingRole?> onRoleChanged;
  final ValueChanged<String?> onBattingStyleChanged;
  final ValueChanged<PlayerBowlingStyle?> onBowlingStyleChanged;

  static final roles = [
    PlayerPlayingRole.batsman,
    PlayerPlayingRole.bowler,
    PlayerPlayingRole.allRounder,
    PlayerPlayingRole.wicketKeeper,
    PlayerPlayingRole.wicketKeeperBatter,
  ];

  static const battingStyles = [
    'Right Hand Bat',
    'Left Hand Bat',
  ];

  static final bowlingStyles = [
    PlayerBowlingStyle.rightArmFast,
    PlayerBowlingStyle.leftArmFast,
    PlayerBowlingStyle.rightArmMedium,
    PlayerBowlingStyle.leftArmMedium,
    PlayerBowlingStyle.rightArmOffSpin,
    PlayerBowlingStyle.rightArmLegSpin,
    PlayerBowlingStyle.leftArmOrthodoxSpin,
    PlayerBowlingStyle.leftArmChinaman,
  ];

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Card(
      elevation: 0,
      color: cf.sectionBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cf.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CfUnderlinedField(
              controller: nameController,
              label: 'Full name',
              required: true,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _dropdownLabel(context, 'Playing role'),
            DropdownButtonFormField<PlayerPlayingRole>(
              value: role,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Select role'),
              items: roles
                  .map(
                    (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                  )
                  .toList(),
              onChanged: onRoleChanged,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _dropdownLabel(context, 'Batting style'),
            DropdownButtonFormField<String>(
              value: battingStyle,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Select batting style'),
              items: battingStyles
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: onBattingStyleChanged,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _dropdownLabel(context, 'Bowling style'),
            DropdownButtonFormField<PlayerBowlingStyle>(
              value: bowlingStyle,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Select bowling style'),
              items: bowlingStyles
                  .map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: onBowlingStyleChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: context.cf.textPrimary,
        ),
      ),
    );
  }
}

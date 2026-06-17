import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/player_profile_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_player_snapshot.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_underlined_field.dart';

/// Bottom sheet: permanently add a team player or create a match-only guest.
Future<MatchPlayerSnapshot?> showAddMatchSquadPlayerSheet(
  BuildContext context, {
  required String teamId,
}) {
  return showModalBottomSheet<MatchPlayerSnapshot>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _AddMatchSquadPlayerSheet(teamId: teamId),
  );
}

class _AddMatchSquadPlayerSheet extends StatefulWidget {
  const _AddMatchSquadPlayerSheet({required this.teamId});

  final String teamId;

  @override
  State<_AddMatchSquadPlayerSheet> createState() =>
      _AddMatchSquadPlayerSheetState();
}

class _AddMatchSquadPlayerSheetState extends State<_AddMatchSquadPlayerSheet> {
  final _nameController = TextEditingController();
  var _mode = _AddMode.choose;
  PlayerPlayingRole? _role;
  String? _battingStyle;
  PlayerBowlingStyle? _bowlingStyle;

  static final _guestRoles = [
    PlayerPlayingRole.batsman,
    PlayerPlayingRole.bowler,
    PlayerPlayingRole.allRounder,
    PlayerPlayingRole.wicketKeeper,
    PlayerPlayingRole.wicketKeeperBatter,
  ];

  static const _guestBattingStyles = [
    'Right Hand Bat',
    'Left Hand Bat',
  ];

  static final _guestBowlingStyles = [
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
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openTeamAddFlow() {
    Navigator.of(context).pop();
    context.push('/teams/${widget.teamId}/add-players/quick');
  }

  void _saveGuest() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Full name is required');
      return;
    }
    if (_role == null) {
      _showError('Playing role is required');
      return;
    }
    if (_battingStyle == null) {
      _showError('Batting style is required');
      return;
    }
    if (_bowlingStyle == null) {
      _showError('Bowling style is required');
      return;
    }

    Navigator.of(context).pop(
      MatchPlayerSnapshot.matchOnly(
        name: name,
        playingRole: _role!.label,
        battingStyle: _battingStyle!,
        bowlingStyle: _bowlingStyle!.label,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd + bottomInset,
      ),
      child: SingleChildScrollView(
        child: switch (_mode) {
          _AddMode.choose => _buildChoose(),
          _AddMode.guest => _buildGuestForm(),
        },
      ),
    );
  }

  Widget _buildChoose() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          'Add player',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Add a permanent team member or a match-only guest player.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        FilledButton.icon(
          onPressed: _openTeamAddFlow,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Add to team permanently'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, AppDimens.buttonHeight),
            backgroundColor: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        OutlinedButton.icon(
          onPressed: () => setState(() => _mode = _AddMode.guest),
          icon: const Icon(Icons.person_outline),
          label: const Text('Add match-only guest'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, AppDimens.buttonHeight),
            foregroundColor: Colors.orange.shade800,
            side: BorderSide(color: Colors.orange.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _mode = _AddMode.choose),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                'Match-only guest',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Guest players exist only for this match and are not added to the team.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        CfUnderlinedField(
          controller: _nameController,
          label: 'Full name',
          required: true,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _dropdownLabel('Playing role'),
        DropdownButtonFormField<PlayerPlayingRole>(
          value: _role,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('Select role'),
          items: _guestRoles
              .map(
                (r) => DropdownMenuItem(value: r, child: Text(r.label)),
              )
              .toList(),
          onChanged: (v) => setState(() => _role = v),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _dropdownLabel('Batting style'),
        DropdownButtonFormField<String>(
          value: _battingStyle,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('Select batting style'),
          items: _guestBattingStyles
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _battingStyle = v),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _dropdownLabel('Bowling style'),
        DropdownButtonFormField<PlayerBowlingStyle>(
          value: _bowlingStyle,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('Select bowling style'),
          items: _guestBowlingStyles
              .map(
                (s) => DropdownMenuItem(value: s, child: Text(s.label)),
              )
              .toList(),
          onChanged: (v) => setState(() => _bowlingStyle = v),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        CfButton(
          label: 'Add guest player',
          onPressed: _saveGuest,
        ),
      ],
    );
  }

  Widget _dropdownLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

enum _AddMode { choose, guest }

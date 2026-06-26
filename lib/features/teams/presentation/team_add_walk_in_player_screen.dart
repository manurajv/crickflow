import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/player_profile_constants.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import '../../../shared/widgets/cf_button.dart';
import 'widgets/walk_in_player_form_fields.dart';

/// Add a walk-in player to the team roster (no CrickFlow account).
class TeamAddWalkInPlayerScreen extends ConsumerStatefulWidget {
  const TeamAddWalkInPlayerScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamAddWalkInPlayerScreen> createState() =>
      _TeamAddWalkInPlayerScreenState();
}

class _TeamAddWalkInPlayerScreenState
    extends ConsumerState<TeamAddWalkInPlayerScreen> {
  final _nameController = TextEditingController();

  PlayerPlayingRole? _role;
  String? _battingStyle;
  PlayerBowlingStyle? _bowlingStyle;
  var _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createAndAdd() async {
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

    setState(() => _creating = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      final playerId = const Uuid().v4();
      final player = PlayerModel(
        id: playerId,
        name: name,
        fullName: name,
        teamIds: [widget.teamId],
        role: _role!.label,
        battingStyle: _battingStyle!,
        bowlingStyle: _bowlingStyle!.label,
        createdBy: uid,
      );

      await ref.read(playerRepositoryProvider).createPlayer(player);
      await ref.read(playerRepositoryProvider).assignPlayerToTeam(
            playerId: playerId,
            teamId: widget.teamId,
            addedByUserId: uid,
          );

      if (!mounted) return;
      ref.invalidate(teamPlayersProvider(widget.teamId));
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to squad')),
      );
    } catch (e) {
      if (mounted) _showError('Could not create player: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Scaffold(
      appBar: AppBar(title: const Text('Walk-in player')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppDimens.listPadding,
              children: [
                Text(
                  'Walk-in player',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add someone who does not have a CrickFlow account — no login or Player ID needed.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                WalkInPlayerFormFields(
                  nameController: _nameController,
                  role: _role,
                  battingStyle: _battingStyle,
                  bowlingStyle: _bowlingStyle,
                  onRoleChanged: (v) => setState(() => _role = v),
                  onBattingStyleChanged: (v) => setState(() => _battingStyle = v),
                  onBowlingStyleChanged: (v) => setState(() => _bowlingStyle = v),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: CfButton(
                label: 'Create & add to squad',
                isLoading: _creating,
                isGold: true,
                onPressed: _creating ? null : _createAndAdd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

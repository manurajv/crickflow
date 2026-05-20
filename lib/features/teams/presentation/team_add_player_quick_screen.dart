import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import '../../../shared/widgets/cf_underlined_field.dart';

/// Quick add: walk-in name or search by email/phone hint.
class TeamAddPlayerQuickScreen extends ConsumerStatefulWidget {
  const TeamAddPlayerQuickScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamAddPlayerQuickScreen> createState() =>
      _TeamAddPlayerQuickScreenState();
}

class _TeamAddPlayerQuickScreenState
    extends ConsumerState<TeamAddPlayerQuickScreen> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _jerseyController = TextEditingController();
  var _role = 'Player';
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player name is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      final playerId = const Uuid().v4();
      final player = PlayerModel(
        id: playerId,
        name: name,
        teamId: widget.teamId,
        jerseyNumber: int.tryParse(_jerseyController.text.trim()),
        role: _role,
        createdBy: uid,
      );
      await ref.read(playerRepositoryProvider).createPlayer(player);
      await ref.read(teamRepositoryProvider).addPlayerToTeam(
            teamId: widget.teamId,
            playerId: playerId,
          );
      ref.invalidate(teamPlayersProvider(widget.teamId));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to squad')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add player: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add player')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spaceLg),
                  child: CfFormFieldGroup(
                    children: [
                      CfUnderlinedField(
                        controller: _nameController,
                        label: 'Player name',
                        required: true,
                      ),
                      CfUnderlinedField(
                        controller: _contactController,
                        label: 'Phone or email',
                        hint: 'Optional — for your reference',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      CfUnderlinedField(
                        controller: _jerseyController,
                        label: 'Jersey number',
                        keyboardType: TextInputType.number,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: CfUnderlinedField.decoration(
                          context,
                          label: 'Role',
                        ),
                        items: const [
                          'Player',
                          'Captain',
                          'Wicket Keeper',
                          'All-rounder',
                        ]
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _role = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add to squad'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

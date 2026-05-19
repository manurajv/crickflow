import 'package:flutter/material.dart';
import '../../data/models/team_model.dart';

/// Pick an existing team or enter a custom name.
class TeamSelector extends StatelessWidget {
  const TeamSelector({
    super.key,
    required this.label,
    required this.teams,
    required this.selectedTeamId,
    required this.customName,
    required this.onTeamSelected,
    required this.onCustomNameChanged,
  });

  final String label;
  final List<TeamModel> teams;
  final String? selectedTeamId;
  final String customName;
  final void Function(TeamModel? team) onTeamSelected;
  final ValueChanged<String> onCustomNameChanged;

  static const String _customValue = '__custom__';

  @override
  Widget build(BuildContext context) {
    final useCustom = selectedTeamId == null;
    final dropdownValue = useCustom ? _customValue : selectedTeamId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: teams.any((t) => t.id == dropdownValue) || useCustom
              ? dropdownValue
              : _customValue,
          decoration: InputDecoration(labelText: label),
          items: [
            ...teams.map(
              (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
            ),
            const DropdownMenuItem(
              value: _customValue,
              child: Text('Custom name…'),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == _customValue) {
              onTeamSelected(null);
            } else {
              final team = teams.firstWhere((t) => t.id == value);
              onTeamSelected(team);
            }
          },
        ),
        if (useCustom) ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: customName,
            decoration: InputDecoration(
              labelText: '$label name',
              hintText: 'Enter team name',
            ),
            onChanged: onCustomNameChanged,
          ),
        ],
      ],
    );
  }
}

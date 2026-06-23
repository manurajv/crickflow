import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';

/// Preset round names organisers can pick when creating a round.
const tournamentRoundPresets = [
  'League Matches',
  'Pre Quarter Final',
  'Quarter Final',
  'Semi Final',
  'Final',
  'Super League',
  'Super Eight',
  'Super Ten',
  'Super Six',
  'Super Four',
  'Super Three',
  'Qualifier 1',
  'Eliminator',
  'Qualifier 2',
  'Third Place',
  'Fourth Place',
  'Fifth Place',
  'Warm Up Match',
  'Relegation Matches',
  'Super Division Matches',
  'Gold Final',
  'Silver Final',
  'Bronze Final',
  'Plate Final',
  'Trophy Final',
  'Plate Playoff',
  'Trophy Playoff',
  'Custom Round',
];

Future<CreateRoundResult?> showCreateRoundDialog(BuildContext context) {
  return showDialog<CreateRoundResult>(
    context: context,
    builder: (ctx) => const _CreateRoundDialog(),
  );
}

class CreateRoundResult {
  const CreateRoundResult({
    required this.name,
    required this.roundType,
    this.description = '',
  });

  final String name;
  final RoundType roundType;
  final String description;
}

class _CreateRoundDialog extends StatefulWidget {
  const _CreateRoundDialog();

  @override
  State<_CreateRoundDialog> createState() => _CreateRoundDialogState();
}

class _CreateRoundDialogState extends State<_CreateRoundDialog> {
  String _preset = tournamentRoundPresets.first;
  final _customName = TextEditingController();
  final _description = TextEditingController();
  RoundType _type = RoundType.league;

  @override
  void dispose() {
    _customName.dispose();
    _description.dispose();
    super.dispose();
  }

  String get _resolvedName =>
      _preset == 'Custom Round' ? _customName.text.trim() : _preset;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create round'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _preset,
              decoration: const InputDecoration(
                labelText: 'Round name',
                border: OutlineInputBorder(),
              ),
              items: tournamentRoundPresets
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _preset = v ?? _preset),
            ),
            if (_preset == 'Custom Round') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customName,
                decoration: const InputDecoration(
                  labelText: 'Custom name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<RoundType>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Round type',
                border: OutlineInputBorder(),
              ),
              items: RoundType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.defaultLabel()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _resolvedName.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    CreateRoundResult(
                      name: _resolvedName,
                      roundType: _type,
                      description: _description.text.trim(),
                    ),
                  ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

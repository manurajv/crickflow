import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/lineup_player.dart';

/// Striker, non-striker, and bowler selection from squad lists.
class PlayerLineupPicker extends StatefulWidget {
  const PlayerLineupPicker({
    super.key,
    required this.battingSquad,
    required this.bowlingSquad,
    this.initialStrikerId,
    this.initialNonStrikerId,
    this.initialBowlerId,
    required this.onSave,
    this.isLoading = false,
  });

  final List<LineupPlayer> battingSquad;
  final List<LineupPlayer> bowlingSquad;
  final String? initialStrikerId;
  final String? initialNonStrikerId;
  final String? initialBowlerId;
  final bool isLoading;
  final void Function({
    required String strikerId,
    required String strikerName,
    required String nonStrikerId,
    required String nonStrikerName,
    required String bowlerId,
    required String bowlerName,
  }) onSave;

  @override
  State<PlayerLineupPicker> createState() => _PlayerLineupPickerState();
}

class _PlayerLineupPickerState extends State<PlayerLineupPicker> {
  LineupPlayer? _striker;
  LineupPlayer? _nonStriker;
  LineupPlayer? _bowler;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(PlayerLineupPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.battingSquad != widget.battingSquad ||
        oldWidget.bowlingSquad != widget.bowlingSquad) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _striker = _pick(
          widget.battingSquad,
          widget.initialStrikerId,
          0,
        ) ??
        widget.battingSquad.firstOrNull;
    _nonStriker = _pick(
          widget.battingSquad,
          widget.initialNonStrikerId,
          1,
        ) ??
        widget.battingSquad.skip(1).firstOrNull ??
        _striker;
    _bowler = _pick(widget.bowlingSquad, widget.initialBowlerId, 0) ??
        widget.bowlingSquad.firstOrNull;
  }

  LineupPlayer? _pick(List<LineupPlayer> squad, String? id, int fallbackIndex) {
    if (id != null) {
      return squad.where((p) => p.id == id).firstOrNull;
    }
    if (squad.length > fallbackIndex) return squad[fallbackIndex];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (widget.battingSquad.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Add players to teams in Firestore, or link team IDs on this match.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lineup',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.gold)),
            const SizedBox(height: 8),
            _playerDropdown(
              'Striker *',
              _striker,
              widget.battingSquad,
              (p) => setState(() => _striker = p),
            ),
            _playerDropdown(
              'Non-striker',
              _nonStriker,
              widget.battingSquad,
              (p) => setState(() => _nonStriker = p),
            ),
            _playerDropdown(
              'Bowler',
              _bowler,
              widget.bowlingSquad.isNotEmpty
                  ? widget.bowlingSquad
                  : widget.battingSquad,
              (p) => setState(() => _bowler = p),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _striker == null || _nonStriker == null || _bowler == null
                    ? null
                    : () {
                        widget.onSave(
                          strikerId: _striker!.id,
                          strikerName: _striker!.name,
                          nonStrikerId: _nonStriker!.id,
                          nonStrikerName: _nonStriker!.name,
                          bowlerId: _bowler!.id,
                          bowlerName: _bowler!.name,
                        );
                      },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Apply lineup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerDropdown(
    String label,
    LineupPlayer? selected,
    List<LineupPlayer> options,
    ValueChanged<LineupPlayer> onChanged,
  ) {
    final value = selected ?? options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<LineupPlayer>(
        value: options.contains(value) ? value : options.first,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: options
            .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
            .toList(),
        onChanged: (p) {
          if (p != null) onChanged(p);
        },
      ),
    );
  }
}

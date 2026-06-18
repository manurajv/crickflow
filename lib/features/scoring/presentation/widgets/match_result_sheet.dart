import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

/// Match result picker — winner, draw, or abandoned.
class MatchResultSheet extends StatefulWidget {
  const MatchResultSheet({
    super.key,
    required this.match,
    required this.onConfirm,
  });

  final MatchModel match;
  final Future<void> Function(MatchResultInput result) onConfirm;

  static Future<void> show(
    BuildContext context, {
    required MatchModel match,
    required Future<void> Function(MatchResultInput result) onConfirm,
  }) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => MatchResultSheet(match: match, onConfirm: onConfirm),
    );
  }

  @override
  State<MatchResultSheet> createState() => _MatchResultSheetState();
}

class MatchResultInput {
  const MatchResultInput({
    this.winnerTeamId,
    this.isDraw = false,
    this.isAbandoned = false,
    this.abandonedReason = '',
    this.considerAllOversForNrr = true,
  });

  final String? winnerTeamId;
  final bool isDraw;
  final bool isAbandoned;
  final String abandonedReason;
  final bool considerAllOversForNrr;
}

class _MatchResultSheetState extends State<MatchResultSheet> {
  String? _winnerTeamId;
  bool _isDraw = false;
  bool _isAbandoned = false;
  bool _considerAllOvers = true;
  String _abandonedReason = 'Rain';
  bool _busy = false;

  static const _abandonReasons = [
    'Rain',
    'Bad Light',
    'Ground Conditions',
    'Other',
  ];

  bool get _winnerDisabled => _isDraw || _isAbandoned;

  Future<void> _confirm() async {
    if (!_isDraw && !_isAbandoned && _winnerTeamId == null) return;
    setState(() => _busy = true);
    try {
      await widget.onConfirm(
        MatchResultInput(
          winnerTeamId: _winnerTeamId,
          isDraw: _isDraw,
          isAbandoned: _isAbandoned,
          abandonedReason: _isAbandoned ? _abandonedReason : '',
          considerAllOversForNrr: _considerAllOvers,
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Match Result'),
            const SizedBox(height: 8),
            const Text(
              'Who won the match?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: _teamCard(
                    teamId: widget.match.teamAId,
                    name: widget.match.teamAName,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _teamCard(
                    teamId: widget.match.teamBId,
                    name: widget.match.teamBName,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            CheckboxListTile(
              value: _isDraw,
              activeColor: AppColors.gold,
              onChanged: (v) => setState(() {
                _isDraw = v ?? false;
                if (_isDraw) {
                  _isAbandoned = false;
                  _winnerTeamId = null;
                }
              }),
              title: const Text('Match Drawn'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _isAbandoned,
              activeColor: AppColors.gold,
              onChanged: (v) => setState(() {
                _isAbandoned = v ?? false;
                if (_isAbandoned) {
                  _isDraw = false;
                  _winnerTeamId = null;
                }
              }),
              title: const Text('Match Abandoned'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_isAbandoned) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _abandonedReason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                items: _abandonReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _abandonedReason = v);
                },
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _considerAllOvers,
              activeColor: AppColors.gold,
              onChanged: (v) => setState(() => _considerAllOvers = v ?? true),
              title: const Text(
                'Consider all overs for NRR calculation',
                style: TextStyle(fontSize: 14),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            FilledButton(
              onPressed: _busy ||
                      (!_isDraw && !_isAbandoned && _winnerTeamId == null)
                  ? null
                  : _confirm,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Result'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamCard({required String? teamId, required String name}) {
    if (teamId == null) return const SizedBox.shrink();
    final selected = !_winnerDisabled && _winnerTeamId == teamId;
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.15)
          : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _winnerDisabled
            ? null
            : () => setState(() {
                  _winnerTeamId = teamId;
                  _isDraw = false;
                  _isAbandoned = false;
                }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            name.isNotEmpty ? name : 'Team',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: _winnerDisabled
                  ? AppColors.textSecondary
                  : selected
                      ? AppColors.gold
                      : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

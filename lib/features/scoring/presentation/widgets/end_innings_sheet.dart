import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

enum EndInningsOption { allOut, declare, penaltyRuns }

/// End Innings sheet with All Out / Declare / Penalty Runs options.
class EndInningsSheet extends StatefulWidget {
  const EndInningsSheet({
    super.key,
    required this.match,
    required this.innings,
    required this.onConfirm,
  });

  final MatchModel match;
  final InningsModel innings;
  final Future<void> Function(EndInningsResult result) onConfirm;

  static Future<void> show(
    BuildContext context, {
    required MatchModel match,
    required InningsModel innings,
    required Future<void> Function(EndInningsResult result) onConfirm,
  }) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: EndInningsSheet(
          match: match,
          innings: innings,
          onConfirm: onConfirm,
        ),
      ),
    );
  }

  @override
  State<EndInningsSheet> createState() => _EndInningsSheetState();
}

class EndInningsResult {
  const EndInningsResult({
    required this.option,
    required this.considerAllOversForNrr,
    this.penaltyRuns = 0,
    this.penaltyReason = '',
  });

  final EndInningsOption option;
  final bool considerAllOversForNrr;
  final int penaltyRuns;
  final String penaltyReason;

  String get endReason => switch (option) {
        EndInningsOption.allOut => 'all_out',
        EndInningsOption.declare => 'declared',
        EndInningsOption.penaltyRuns => 'penalty',
      };
}

class _EndInningsSheetState extends State<EndInningsSheet> {
  EndInningsOption _option = EndInningsOption.allOut;
  bool _considerAllOvers = true;
  int _penaltyRuns = 0;
  final _penaltyReasonCtrl = TextEditingController();
  final _penaltyRunsCtrl = TextEditingController(text: '0');
  bool _busy = false;

  @override
  void dispose() {
    _penaltyReasonCtrl.dispose();
    _penaltyRunsCtrl.dispose();
    super.dispose();
  }

  String get _nrrNote {
    final rules = widget.match.rules;
    if (_option == EndInningsOption.declare) {
      final overs = CricketMath.formatOvers(
        widget.innings.legalBalls,
        rules.ballsPerOver,
      );
      return 'Only $overs overs will be considered for NRR.';
    }
    return 'All overs will be considered for NRR.';
  }

  Future<void> _confirm() async {
    if (_option == EndInningsOption.penaltyRuns &&
        _penaltyRuns != 0 &&
        _penaltyReasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Penalty reason is required')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onConfirm(
        EndInningsResult(
          option: _option,
          considerAllOversForNrr: _considerAllOvers,
          penaltyRuns: _option == EndInningsOption.penaltyRuns
              ? _penaltyRuns
              : 0,
          penaltyReason: _penaltyReasonCtrl.text.trim(),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScoringSheetHeader(title: 'End Innings'),
            const SizedBox(height: AppDimens.spaceMd),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _optionCard(
                    EndInningsOption.allOut,
                    'All Out',
                    'Batting team all out',
                    Icons.sports_cricket_outlined,
                  ),
                  const SizedBox(width: 10),
                  _optionCard(
                    EndInningsOption.declare,
                    'Declare Innings',
                    'Voluntary declaration',
                    Icons.flag_outlined,
                  ),
                  const SizedBox(width: 10),
                  _optionCard(
                    EndInningsOption.penaltyRuns,
                    'Penalty Runs',
                    'Adjust score before closure',
                    Icons.gavel_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              _nrrNote,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (_option == EndInningsOption.penaltyRuns) ...[
              const SizedBox(height: AppDimens.spaceMd),
              const Text(
                'Penalty Runs',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: () {
                      setState(() {
                        _penaltyRuns--;
                        _penaltyRunsCtrl.text = '$_penaltyRuns';
                      });
                    },
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      controller: _penaltyRunsCtrl,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) setState(() => _penaltyRuns = n);
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      setState(() {
                        _penaltyRuns++;
                        _penaltyRunsCtrl.text = '$_penaltyRuns';
                      });
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              TextField(
                controller: _penaltyReasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spaceMd),
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
              onPressed: _busy ? null : _confirm,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionCard(
    EndInningsOption option,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _option == option;
    return SizedBox(
      width: 140,
      child: Material(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _option = option),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? AppColors.gold : AppColors.textSecondary),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? AppColors.gold : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

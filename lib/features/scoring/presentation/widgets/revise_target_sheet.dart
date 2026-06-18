import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/repositories/match_target_revision_repository.dart';
import '../../../../domain/scoring/innings_completion_policy.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

enum ReviseTargetMethod { dls, other }

enum FirstInningsAction { continueInnings, endInnings }

/// Revise Target — scorer-assisted DLS and manual target revision.
class ReviseTargetSheet extends StatefulWidget {
  const ReviseTargetSheet({
    super.key,
    required this.match,
    required this.innings,
    required this.onApplyDls,
    required this.onApplyManual,
    required this.onEndInnings,
  });

  final MatchModel match;
  final InningsModel innings;
  final Future<void> Function(ScorerDlsRevisionInput input) onApplyDls;
  final Future<void> Function(int revisedTarget, String reason) onApplyManual;
  final VoidCallback onEndInnings;

  static Future<void> show(
    BuildContext context, {
    required MatchModel match,
    required InningsModel innings,
    required Future<void> Function(ScorerDlsRevisionInput input) onApplyDls,
    required Future<void> Function(int revisedTarget, String reason)
        onApplyManual,
    required VoidCallback onEndInnings,
  }) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: ReviseTargetSheet(
          match: match,
          innings: innings,
          onApplyDls: onApplyDls,
          onApplyManual: onApplyManual,
          onEndInnings: onEndInnings,
        ),
      ),
    );
  }

  @override
  State<ReviseTargetSheet> createState() => _ReviseTargetSheetState();
}

class _ReviseTargetSheetState extends State<ReviseTargetSheet> {
  ReviseTargetMethod _method = ReviseTargetMethod.dls;
  FirstInningsAction _firstInningsAction = FirstInningsAction.continueInnings;
  final _oversToCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isSecondInnings =>
      widget.innings.inningsNumber >= 2 && !widget.innings.isSuperOver;

  int get _originalOvers {
    final state = widget.match.targetState;
    final rules =
        InningsCompletionPolicy.effectiveRules(widget.match, widget.innings);
    return state.originalOvers ?? rules.totalOvers;
  }

  int get _currentAllocatedOvers {
    final rules =
        InningsCompletionPolicy.effectiveRules(widget.match, widget.innings);
    return rules.totalOvers;
  }

  int get _oversReducedFrom =>
      _isSecondInnings ? _currentAllocatedOvers : _originalOvers;

  bool get _dlsNeedsTarget =>
      _firstInningsAction == FirstInningsAction.endInnings;

  @override
  void initState() {
    super.initState();
    final rules =
        InningsCompletionPolicy.effectiveRules(widget.match, widget.innings);
    final toOvers =
        widget.match.targetState.revisedOvers ?? rules.totalOvers;
    _oversToCtrl.text = '$toOvers';

    if (_isSecondInnings) {
      final current =
          InningsCompletionPolicy.chaseTarget(widget.match, widget.innings);
      _targetCtrl.text = '$current';
    } else {
      final pending = widget.match.targetState.pendingChaseTarget ??
          widget.match.targetState.revisedTarget;
      if (pending != null) {
        _targetCtrl.text = '$pending';
      }
    }
  }

  @override
  void dispose() {
    _oversToCtrl.dispose();
    _targetCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (_isSecondInnings) {
        final to = int.tryParse(_oversToCtrl.text.trim());
        final target = int.tryParse(_targetCtrl.text.trim());
        if (to == null || to <= 0 || to >= _oversReducedFrom) {
          throw ArgumentError(
            'Reduced overs must be less than $_oversReducedFrom',
          );
        }
        if (target == null || target <= 0) {
          throw ArgumentError('Enter a valid revised target');
        }
        await widget.onApplyDls(
          ScorerDlsRevisionInput(
            originalOvers: _oversReducedFrom,
            revisedOvers: to,
            revisedTarget: target,
            reason: _reasonCtrl.text.trim(),
          ),
        );
      } else if (_method == ReviseTargetMethod.dls) {
        final to = int.tryParse(_oversToCtrl.text.trim());
        if (to == null || to <= 0 || to >= _oversReducedFrom) {
          throw ArgumentError(
            'Reduced overs must be less than $_oversReducedFrom',
          );
        }
        int? target;
        if (_dlsNeedsTarget) {
          target = int.tryParse(_targetCtrl.text.trim());
          if (target == null || target <= 0) {
            throw ArgumentError('Enter the revised target from officials');
          }
        }
        final input = ScorerDlsRevisionInput(
          originalOvers: _oversReducedFrom,
          revisedOvers: to,
          revisedTarget: target,
          reason: _reasonCtrl.text.trim(),
          continueInnings:
              _firstInningsAction == FirstInningsAction.continueInnings,
        );
        await widget.onApplyDls(input);
        if (!mounted) return;
        Navigator.pop(context);
        if (_firstInningsAction == FirstInningsAction.endInnings) {
          widget.onEndInnings();
        }
        return;
      } else {
        if (_firstInningsAction == FirstInningsAction.endInnings) {
          Navigator.pop(context);
          widget.onEndInnings();
          return;
        }
        final target = int.tryParse(_targetCtrl.text.trim());
        if (target == null || target <= 0) {
          throw ArgumentError('Enter a valid revised target');
        }
        await widget.onApplyManual(target, _reasonCtrl.text.trim());
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('ArgumentError: ', ''));
      }
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
            const ScoringSheetHeader(title: 'Revise Target'),
            if (_isSecondInnings) ...[
              _buildSecondInningsForm(),
            ] else ...[
              _buildFirstInningsForm(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFE53935), fontSize: 13),
              ),
            ],
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _apply,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondInningsForm() {
    final current =
        InningsCompletionPolicy.chaseTarget(widget.match, widget.innings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Current Target: $current',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Overs Reduced From',
            border: OutlineInputBorder(),
          ),
          child: Text(
            '$_oversReducedFrom overs',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _oversToCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Overs Reduced To',
            helperText: 'Must be less than $_oversReducedFrom',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        TextField(
          controller: _targetCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Revised Target',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        TextField(
          controller: _reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstInningsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioListTile<ReviseTargetMethod>(
          value: ReviseTargetMethod.dls,
          groupValue: _method,
          activeColor: AppColors.gold,
          title: const Text('Apply DLS Method'),
          subtitle: const Text(
            'Reduce overs now; enter target only when ending innings',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (v) => setState(() => _method = v!),
        ),
        if (_method == ReviseTargetMethod.dls) ...[
          const SizedBox(height: AppDimens.spaceSm),
          _firstInningsActionCards(),
          const SizedBox(height: AppDimens.spaceMd),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Overs Reduced From',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    '$_oversReducedFrom overs',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _oversToCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Overs Reduced To',
                    helperText: 'Must be less than $_oversReducedFrom',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_dlsNeedsTarget) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _targetCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Revised Target',
                      helperText: 'Target for chase innings (from officials)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
        RadioListTile<ReviseTargetMethod>(
          value: ReviseTargetMethod.other,
          groupValue: _method,
          activeColor: AppColors.gold,
          title: const Text('Apply Other Method'),
          onChanged: (v) => setState(() => _method = v!),
        ),
        if (_method == ReviseTargetMethod.other) ...[
          const SizedBox(height: 8),
          _firstInningsActionCards(),
          if (_firstInningsAction == FirstInningsAction.continueInnings) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    controller: _targetCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Revised Target',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _firstInningsActionCards() {
    return Column(
      children: [
        _actionCard(
          title: 'Continue Innings',
          subtitle: 'Reduce overs only — keep batting',
          selected: _firstInningsAction == FirstInningsAction.continueInnings,
          onTap: () => setState(
            () => _firstInningsAction = FirstInningsAction.continueInnings,
          ),
        ),
        const SizedBox(height: 8),
        _actionCard(
          title: 'End Innings',
          subtitle: 'Set revised target and close innings',
          selected: _firstInningsAction == FirstInningsAction.endInnings,
          onTap: () => setState(
            () => _firstInningsAction = FirstInningsAction.endInnings,
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.12)
          : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.gold : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

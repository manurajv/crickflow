import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../data/models/match_rules_model.dart';

/// Shared wd / nb / ww rules editor (match scoring rules screen + tournament rules).
class MatchScoringRulesForm extends StatelessWidget {
  const MatchScoringRulesForm({
    super.key,
    required this.rules,
    required this.onChanged,
    this.enabled = true,
    this.showMatchFormatFields = false,
    this.oversController,
    this.oversPerBowlerController,
    this.onTotalOversChanged,
    this.onOversPerBowlerChanged,
  });

  final MatchRulesModel rules;
  final ValueChanged<MatchRulesModel> onChanged;
  final bool enabled;
  final bool showMatchFormatFields;
  final TextEditingController? oversController;
  final TextEditingController? oversPerBowlerController;
  final ValueChanged<int>? onTotalOversChanged;
  final ValueChanged<int>? onOversPerBowlerChanged;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final wwLocked = rules.isIndoor;
    final showOvers = !rules.isTestMatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showMatchFormatFields && showOvers) ...[
          const MatchScoringRulesSectionTitle('Match format'),
          if (oversController != null)
            MatchScoringRulesTextField(
              controller: oversController!,
              label: 'Overs per match',
              enabled: enabled,
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) {
                  onTotalOversChanged?.call(n);
                  onChanged(rules.withTotalOvers(n));
                }
              },
            )
          else
            MatchScoringRulesStepperRow(
              label: 'Overs per match',
              value: rules.totalOvers,
              min: 1,
              max: 50,
              enabled: enabled,
              onChanged: (v) => onChanged(rules.withTotalOvers(v)),
            ),
          const SizedBox(height: AppDimens.spaceSm),
          if (oversPerBowlerController != null)
            MatchScoringRulesTextField(
              controller: oversPerBowlerController!,
              label: 'Overs per bowler',
              enabled: enabled,
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n >= 1) {
                  onOversPerBowlerChanged?.call(n);
                  onChanged(rules.withManualOversPerBowler(n));
                }
              },
            )
          else
            MatchScoringRulesStepperRow(
              label: 'Overs per bowler',
              value: rules.oversPerBowler,
              min: 1,
              max: rules.totalOvers.clamp(1, 50),
              enabled: enabled,
              onChanged: (v) => onChanged(rules.withManualOversPerBowler(v)),
            ),
          MatchScoringRulesStepperRow(
            label: 'Players per team',
            value: rules.playersPerTeam,
            min: 1,
            max: 25,
            enabled: enabled,
            onChanged: (v) => onChanged(
              rules.copyWith(
                playersPerTeam: MatchRulesModel.clampPlayersPerTeam(v),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        const MatchScoringRulesSectionTitle('Over settings'),
        MatchScoringRulesStepperRow(
          label: 'Balls per over',
          value: rules.ballsPerOver,
          min: 1,
          max: 12,
          enabled: enabled,
          onChanged: (v) => onChanged(
            rules.copyWith(
              ballsPerOver: MatchRulesModel.clampBallsPerOver(v),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const MatchScoringRulesSectionTitle('Wagon wheel'),
        MatchScoringRulesSwitch(
          label: 'Enable wagon wheel tracking',
          value: rules.wagonWheelEnabled,
          enabled: enabled && !wwLocked,
          onChanged: (v) => onChanged(
            rules.copyWith(
              wagonWheelEnabled: v,
              wagonWheelDots: v,
              wagonWheelRuns123: v,
              wagonWheelShotSelection: v,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
          child: Text(
            wwLocked
                ? 'Wagon wheel is off for indoor matches.'
                : 'When on, scorers mark shot direction for runs 1–6 '
                    'and no-ball off the bat. Wide, bye, leg bye, and '
                    'penalty runs are skipped.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
        const MatchScoringRulesSectionTitle('Wide / no ball rules'),
        MatchScoringRulesSwitch(
          label: 'Count wide as a legal delivery (A)',
          value: rules.wideCountsAsLegalDelivery,
          enabled: enabled,
          onChanged: (v) =>
              onChanged(rules.copyWith(wideCountsAsLegalDelivery: v)),
        ),
        MatchScoringRulesStepperRow(
          label: 'Wide runs (B)',
          value: rules.wideRuns,
          min: 0,
          max: 10,
          enabled: enabled,
          onChanged: (v) => onChanged(rules.copyWith(wideRuns: v)),
        ),
        MatchScoringRulesSwitch(
          label: 'Count no ball as a legal delivery (C)',
          value: rules.noBallCountsAsLegalDelivery,
          enabled: enabled,
          onChanged: (v) =>
              onChanged(rules.copyWith(noBallCountsAsLegalDelivery: v)),
        ),
        MatchScoringRulesStepperRow(
          label: 'No ball runs (D)',
          value: rules.noBallRuns,
          min: 0,
          max: 10,
          enabled: enabled,
          onChanged: (v) => onChanged(rules.copyWith(noBallRuns: v)),
        ),
      ],
    );
  }
}

class MatchScoringRulesSectionTitle extends StatelessWidget {
  const MatchScoringRulesSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class MatchScoringRulesSwitch extends StatelessWidget {
  const MatchScoringRulesSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: cf.accent,
    );
  }
}

class MatchScoringRulesStepperRow extends StatelessWidget {
  const MatchScoringRulesStepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.enabled = true,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: cf.sectionBackground,
              foregroundColor: cf.textPrimary,
            ),
            onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: cf.sectionBackground,
              foregroundColor: cf.textPrimary,
            ),
            onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class MatchScoringRulesTextField extends StatelessWidget {
  const MatchScoringRulesTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const UnderlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

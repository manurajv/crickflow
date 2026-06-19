import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../core/theme/cf_colors.dart';

/// Wide / no-ball rule controls shared by match setup and rules edit screens.
class MatchWideNoBallRulesSection extends StatelessWidget {
  const MatchWideNoBallRulesSection({
    super.key,
    required this.rules,
    required this.onChanged,
  });

  final MatchRulesModel rules;
  final ValueChanged<MatchRulesModel> onChanged;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SubLabel('Wide / no ball'),
        const SizedBox(height: AppDimens.spaceSm),
        _RuleSwitch(
          label: 'Count wide as a legal delivery',
          value: rules.wideCountsAsLegalDelivery,
          onChanged: (v) => onChanged(rules.copyWith(wideCountsAsLegalDelivery: v)),
        ),
        _StepperRow(
          label: 'Wide runs',
          value: rules.wideRuns,
          min: 0,
          max: 10,
          onChanged: (v) => onChanged(rules.copyWith(wideRuns: v)),
        ),
        _RuleSwitch(
          label: 'Count no ball as a legal delivery',
          value: rules.noBallCountsAsLegalDelivery,
          onChanged: (v) =>
              onChanged(rules.copyWith(noBallCountsAsLegalDelivery: v)),
        ),
        _StepperRow(
          label: 'No ball runs',
          value: rules.noBallRuns,
          min: 0,
          max: 10,
          onChanged: (v) => onChanged(rules.copyWith(noBallRuns: v)),
        ),
      ],
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: cf.textSecondary,
      ),
    );
  }
}

class _RuleSwitch extends StatelessWidget {
  const _RuleSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: cf.accent,
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: cf.sectionBackground,
              foregroundColor: cf.textPrimary,
              minimumSize: const Size(36, 36),
            ),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$value', style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: cf.sectionBackground,
              foregroundColor: cf.textPrimary,
              minimumSize: const Size(36, 36),
            ),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

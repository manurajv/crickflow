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
        const SizedBox(height: AppDimens.spaceMd),
        const Divider(height: 1),
        const SizedBox(height: AppDimens.spaceSm),
        const _SubLabel('Match rules'),
        const SizedBox(height: AppDimens.spaceSm),
        _RuleDropdown<bool>(
          label: 'Free Hits',
          description: 'Allow a free hit after a No Ball.',
          value: rules.freeHitEnabled,
          items: const [
            (true, 'Enabled'),
            (false, 'Disabled'),
          ],
          onChanged: (v) => onChanged(rules.copyWith(freeHitEnabled: v)),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _RuleDropdown<bool>(
          label: 'Wicket Keeper Can Bowl',
          description:
              'Allow the designated wicket keeper to bowl during the match.',
          value: rules.wicketKeeperCanBowl,
          items: const [
            (true, 'Allowed'),
            (false, 'Not Allowed'),
          ],
          onChanged: (v) => onChanged(rules.copyWith(wicketKeeperCanBowl: v)),
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

class _RuleDropdown<T> extends StatelessWidget {
  const _RuleDropdown({
    required this.label,
    required this.description,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String description;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          key: ValueKey<T>(value),
          initialValue: value,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item.$1,
                child: Text(item.$2),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            fontSize: 11,
            color: cf.textMuted,
            height: 1.4,
          ),
        ),
      ],
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

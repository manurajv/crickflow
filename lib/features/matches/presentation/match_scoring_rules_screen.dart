import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_rules_model.dart';

/// Wide / no-ball / wagon wheel scoring rules (reference: Match rules wd, nb, ww).
class MatchScoringRulesScreen extends StatefulWidget {
  const MatchScoringRulesScreen({
    super.key,
    required this.initialRules,
  });

  final MatchRulesModel initialRules;

  @override
  State<MatchScoringRulesScreen> createState() =>
      _MatchScoringRulesScreenState();
}

class _MatchScoringRulesScreenState extends State<MatchScoringRulesScreen> {
  late MatchRulesModel _rules;

  @override
  void initState() {
    super.initState();
    _rules = widget.initialRules;
  }

  void _update(MatchRulesModel r) => setState(() => _rules = r);

  void _reset() => _update(widget.initialRules);

  @override
  Widget build(BuildContext context) {
    final wwLocked = _rules.isIndoor;

    return Scaffold(
      appBar: AppBar(title: const Text('Match rules (wd, nb, ww)')),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          _SectionTitle('Wagon wheel'),
          _RuleSwitch(
            label: 'Show wagon wheel for dot balls',
            value: _rules.wagonWheelDots,
            enabled: !wwLocked,
            onChanged: (v) => _update(_rules.copyWith(wagonWheelDots: v)),
          ),
          _RuleSwitch(
            label: 'Show wagon wheel for 1s, 2s & 3s',
            value: _rules.wagonWheelRuns123,
            enabled: !wwLocked,
            onChanged: (v) => _update(_rules.copyWith(wagonWheelRuns123: v)),
          ),
          _RuleSwitch(
            label: 'Shot selection',
            value: _rules.wagonWheelShotSelection,
            enabled: !wwLocked,
            onChanged: (v) =>
                _update(_rules.copyWith(wagonWheelShotSelection: v)),
          ),
          if (wwLocked)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              child: Text(
                'Wagon wheel is off for indoor matches.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              child: Text(
                '* WW and shot selection stay on for boundaries and wickets.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
            ),
          ),
          _SectionTitle('Wide / no ball rules'),
          _RuleSwitch(
            label: 'Count wide as a legal delivery (A)',
            value: _rules.wideCountsAsLegalDelivery,
            onChanged: (v) =>
                _update(_rules.copyWith(wideCountsAsLegalDelivery: v)),
          ),
          _StepperRow(
            label: 'Wide runs (B)',
            value: _rules.wideRuns,
            min: 0,
            max: 10,
            onChanged: (v) => _update(_rules.copyWith(wideRuns: v)),
          ),
          _RuleSwitch(
            label: 'Count no ball as a legal delivery (C)',
            value: _rules.noBallCountsAsLegalDelivery,
            onChanged: (v) =>
                _update(_rules.copyWith(noBallCountsAsLegalDelivery: v)),
          ),
          _StepperRow(
            label: 'No ball runs (D)',
            value: _rules.noBallRuns,
            min: 0,
            max: 10,
            onChanged: (v) => _update(_rules.copyWith(noBallRuns: v)),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _SectionTitle('Impact player'),
          _RuleSwitch(
            label: 'Enable impact player rule',
            value: _rules.impactPlayerEnabled,
            onChanged: (v) => _update(_rules.copyWith(impactPlayerEnabled: v)),
          ),
          const SizedBox(height: AppDimens.spaceXl),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size(0, AppDimens.buttonHeightLarge),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _rules),
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size(0, AppDimens.buttonHeightLarge),
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

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

class _RuleSwitch extends StatelessWidget {
  const _RuleSwitch({
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
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: AppColors.gold,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: value > min ? () => onChanged(value - 1) : null,
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
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

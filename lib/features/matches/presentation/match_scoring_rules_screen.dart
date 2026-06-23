import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/match_rules_model.dart';
import '../../../shared/widgets/match_scoring_rules_form.dart';
import '../../../shared/widgets/scoring_ui_kit.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Match rules (wd, nb, ww)')),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          MatchScoringRulesForm(
            rules: _rules,
            onChanged: _update,
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
                  style: ScoringUiKit.primaryButtonStyle(context).copyWith(
                    minimumSize: WidgetStateProperty.all(
                      const Size(0, AppDimens.buttonHeightLarge),
                    ),
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

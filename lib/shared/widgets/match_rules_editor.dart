import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/match_rules_model.dart';

class MatchRulesEditor extends StatefulWidget {
  const MatchRulesEditor({
    super.key,
    required this.rules,
    required this.onChanged,
  });

  final MatchRulesModel rules;
  final ValueChanged<MatchRulesModel> onChanged;

  @override
  State<MatchRulesEditor> createState() => _MatchRulesEditorState();
}

class _MatchRulesEditorState extends State<MatchRulesEditor> {
  late MatchRulesModel _rules;

  @override
  void initState() {
    super.initState();
    _rules = widget.rules;
  }

  void _update(MatchRulesModel r) {
    setState(() => _rules = r);
    widget.onChanged(r);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Match Format',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<MatchFormat>(
          segments: const [
            ButtonSegment(value: MatchFormat.standard, label: Text('Standard')),
            ButtonSegment(value: MatchFormat.tennis, label: Text('Tennis')),
            ButtonSegment(value: MatchFormat.custom, label: Text('Custom')),
          ],
          selected: {_rules.format},
          onSelectionChanged: (s) {
            final f = s.first;
            if (f == MatchFormat.tennis) {
              _update(MatchRulesModel.tennisCricket());
            } else if (f == MatchFormat.standard) {
              _update(MatchRulesModel.standardT20());
            } else {
              _update(
                _rules.copyWith(
                  format: f,
                  ballType: MatchRulesModel.defaultBallTypeFor(f),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        const Text('Ball type',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<CricketBallType>(
          segments: const [
            ButtonSegment(
              value: CricketBallType.leather,
              label: Text('Leather'),
            ),
            ButtonSegment(
              value: CricketBallType.tennis,
              label: Text('Tennis'),
            ),
            ButtonSegment(
              value: CricketBallType.indoor,
              label: Text('Indoor'),
            ),
          ],
          selected: {_rules.resolvedBallType},
          onSelectionChanged: (s) {
            _update(_rules.copyWith(ballType: s.first));
          },
        ),
        const SizedBox(height: 20),
        _numField('Total Overs', _rules.totalOvers, (v) {
          _update(_rules.copyWith(totalOvers: v));
        }),
        _numField('Balls per Over', _rules.ballsPerOver, (v) {
          _update(_rules.copyWith(ballsPerOver: v));
        }),
        _numField('Wide Runs', _rules.wideRuns, (v) {
          _update(_rules.copyWith(wideRuns: v));
        }),
        _numField('No Ball Runs', _rules.noBallRuns, (v) {
          _update(_rules.copyWith(noBallRuns: v));
        }),
        _numField('Max Wickets', _rules.maxWickets, (v) {
          _update(_rules.copyWith(maxWickets: v));
        }),
        _numField('Max Innings', _rules.maxInnings, (v) {
          _update(_rules.copyWith(maxInnings: v));
        }),
        SwitchListTile(
          title: const Text('Free Hit on No Ball'),
          value: _rules.freeHitEnabled,
          onChanged: (v) => _update(_rules.copyWith(freeHitEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('Last Man Standing'),
          value: _rules.lastManStanding,
          onChanged: (v) => _update(_rules.copyWith(lastManStanding: v)),
        ),
      ],
    );
  }

  Widget _numField(String label, int value, ValueChanged<int> onChanged) {
    return TextFormField(
      initialValue: value.toString(),
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      onChanged: (t) {
        final v = int.tryParse(t);
        if (v != null) onChanged(v);
      },
    );
  }
}

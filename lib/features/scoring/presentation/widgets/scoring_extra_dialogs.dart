import 'package:flutter/material.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../domain/services/scoring_engine.dart';

/// Wide / no-ball / bye / leg-bye dialogs (reference-style).
class ScoringExtraDialogs {
  ScoringExtraDialogs._();

  static Future<BallEventInput?> showWide(
    BuildContext context, {
    required MatchRulesModel rules,
  }) async {
    var extra = 0;
    return showDialog<BallEventInput>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final total = rules.wideRuns + extra;
          return AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('Wide ball'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('WD + '),
                SizedBox(
                  width: 48,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (v) =>
                        setState(() => extra = int.tryParse(v) ?? 0),
                  ),
                ),
                Text(' = $total ${total == 1 ? 'run' : 'runs'}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  BallEventInput(type: BallEventType.wide, runs: extra),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<BallEventInput?> showNoBall(
    BuildContext context, {
    required MatchRulesModel rules,
  }) async {
    var extra = 0;
    var fromBat = true;
    return showDialog<BallEventInput>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final total = rules.noBallRuns + extra;
          return AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('No ball'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('NB + '),
                    SizedBox(
                      width: 48,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (v) =>
                            setState(() => extra = int.tryParse(v) ?? 0),
                      ),
                    ),
                    Text(' = $total runs'),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceMd),
                RadioListTile<bool>(
                  title: const Text('From bat'),
                  value: true,
                  groupValue: fromBat,
                  onChanged: (v) => setState(() => fromBat = v ?? true),
                ),
                RadioListTile<bool>(
                  title: const Text('Bye'),
                  value: false,
                  groupValue: fromBat,
                  onChanged: (v) => setState(() => fromBat = false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  ctx,
                  BallEventInput(
                    type: BallEventType.noBall,
                    runs: fromBat ? extra : 0,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<BallEventInput?> showBye(BuildContext context) async {
    var runs = 1;
    return showDialog<BallEventInput>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Bye'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 56,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Runs'),
                  onChanged: (v) => setState(() => runs = int.tryParse(v) ?? 1),
                ),
              ),
              const SizedBox(width: 8),
              const Text('runs'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                BallEventInput(type: BallEventType.bye, runs: runs.clamp(0, 6)),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<BallEventInput?> showLegBye(BuildContext context) async {
    var runs = 1;
    return showDialog<BallEventInput>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Leg bye'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 56,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (v) => setState(() => runs = int.tryParse(v) ?? 1),
                ),
              ),
              const SizedBox(width: 8),
              const Text('runs'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                BallEventInput(
                  type: BallEventType.legBye,
                  runs: runs.clamp(0, 6),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}

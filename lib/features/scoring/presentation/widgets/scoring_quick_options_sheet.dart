import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

class ScoringQuickOptionsSheet extends StatelessWidget {
  const ScoringQuickOptionsSheet({
    super.key,
    required this.onEditLineup,
    required this.onEndInnings,
    required this.onScorecard,
    required this.onMatchRules,
    this.onEditToss,
  });

  final VoidCallback onEditLineup;
  final VoidCallback onEndInnings;
  final VoidCallback onScorecard;
  final VoidCallback onMatchRules;
  final VoidCallback? onEditToss;

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      if (onEditToss != null)
        _Shortcut(Icons.monetization_on_outlined, 'Change toss', onEditToss!),
      _Shortcut(Icons.help_outline, 'Need help', () {}),
      _Shortcut(Icons.rule, 'Match rules', onMatchRules),
      _Shortcut(Icons.swap_horiz, 'Change scorer', () {}),
      _Shortcut(Icons.group_outlined, 'Change squad', onEditLineup),
      _Shortcut(Icons.table_chart_outlined, 'Full scorecard', onScorecard),
      _Shortcut(Icons.edit_outlined, 'Match overs', () {}),
      _Shortcut(Icons.sync, 'Replace batters', onEditLineup),
      _Shortcut(Icons.add_circle_outline, 'Bonus runs', () {}),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScoringSheetHeader(title: 'Select a shortcut'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.85,
                ),
                itemCount: shortcuts.length,
                itemBuilder: (context, i) {
                  final s = shortcuts[i];
                  return ScoringShortcutTile(
                    icon: s.icon,
                    label: s.label,
                    onTap: () {
                      Navigator.pop(context);
                      s.onTap();
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onEndInnings();
              },
              child: const Text(
                'End innings',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

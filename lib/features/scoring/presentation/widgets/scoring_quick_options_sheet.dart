import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class ScoringQuickOptionsSheet extends StatelessWidget {
  const ScoringQuickOptionsSheet({
    super.key,
    required this.onEditLineup,
    required this.onUndo,
    required this.onEndInnings,
    required this.onScorecard,
    required this.onMatchRules,
  });

  final VoidCallback onEditLineup;
  final VoidCallback onUndo;
  final VoidCallback onEndInnings;
  final VoidCallback onScorecard;
  final VoidCallback onMatchRules;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppDimens.spaceMd),
            child: Text(
              'Quick options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
          const Divider(height: 1),
          _tile(Icons.people_outline, 'Change lineup', onEditLineup),
          _tile(Icons.undo, 'Undo last ball', onUndo),
          _tile(Icons.rule, 'Match rules', onMatchRules),
          _tile(Icons.scoreboard, 'View scorecard', onScorecard),
          _tile(Icons.stop_circle_outlined, 'End innings', onEndInnings),
          const SizedBox(height: AppDimens.spaceMd),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(label),
      onTap: onTap,
    );
  }
}

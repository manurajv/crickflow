import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import 'facing_problem_sheet.dart';
import 'scoring_mistake_sheet.dart';

/// Need Help hub from quick shortcuts.
class NeedHelpSheet extends StatelessWidget {
  const NeedHelpSheet({super.key, required this.matchId});

  final String matchId;

  static Future<void> show(
    BuildContext context, {
    required String matchId,
  }) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      builder: (_) => NeedHelpSheet(matchId: matchId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScoringSheetHeader(title: 'Need Help'),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.gold),
              title: const Text('Scoring Mistake'),
              subtitle: const Text('Undo history & recent balls'),
              onTap: () {
                Navigator.pop(context);
                ScoringMistakeSheet.show(context, matchId: matchId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined,
                  color: AppColors.gold),
              title: const Text('Facing Problem'),
              subtitle: const Text('Report app or scoring issues'),
              onTap: () {
                Navigator.pop(context);
                FacingProblemSheet.show(context, matchId: matchId);
              },
            ),
          ],
        ),
      ),
    );
  }
}

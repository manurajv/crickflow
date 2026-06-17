import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

enum OverCompletionChoice { endOver, continueOver }

/// Shown when configured legal-ball count is reached — scorer chooses next step.
class OverCompletionPromptDialog extends StatelessWidget {
  const OverCompletionPromptDialog({
    super.key,
    required this.legalDeliveries,
    required this.expectedBalls,
  });

  final int legalDeliveries;
  final int expectedBalls;

  static Future<OverCompletionChoice?> show(
    BuildContext context, {
    required int legalDeliveries,
    required int expectedBalls,
  }) {
    return ScoringUiKit.showSheet<OverCompletionChoice>(
      context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => OverCompletionPromptDialog(
        legalDeliveries: legalDeliveries,
        expectedBalls: expectedBalls,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Over complete'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Legal deliveries: $legalDeliveries / $expectedBalls\n\n'
                'What would you like to do?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(context, OverCompletionChoice.endOver),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text(
                  'End over',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(
                  context,
                  OverCompletionChoice.continueOver,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.gold),
                ),
                child: const Text(
                  'Continue over',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

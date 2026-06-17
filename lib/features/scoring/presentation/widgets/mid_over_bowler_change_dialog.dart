import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

/// Confirmation + optional reason when changing bowler during an active over.
class MidOverBowlerChangeDialog extends StatefulWidget {
  const MidOverBowlerChangeDialog({
    super.key,
    required this.overDisplay,
    required this.ballInOver,
  });

  final String overDisplay;
  final int ballInOver;

  static const reasons = [
    'Injury',
    'Umpire Decision',
    'Scoring Correction',
    'Other',
  ];

  static Future<String?> show(
    BuildContext context, {
    required String overDisplay,
    required int ballInOver,
  }) {
    return ScoringUiKit.showSheet<String>(
      context,
      isDismissible: true,
      isScrollControlled: true,
      builder: (ctx) => MidOverBowlerChangeDialog(
        overDisplay: overDisplay,
        ballInOver: ballInOver,
      ),
    );
  }

  @override
  State<MidOverBowlerChangeDialog> createState() =>
      _MidOverBowlerChangeDialogState();
}

class _MidOverBowlerChangeDialogState extends State<MidOverBowlerChangeDialog> {
  String? _selected;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String? get _resolvedReason {
    if (_selected == null) return null;
    if (_selected == 'Other') {
      final note = _noteController.text.trim();
      return note.isEmpty ? null : note;
    }
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Change bowler mid-over'),
            Text(
              'You are changing the bowler during an active over '
              '(${widget.overDisplay}.${widget.ballInOver}).',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason (optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...MidOverBowlerChangeDialog.reasons.map(
              (reason) => RadioListTile<String>(
                value: reason,
                groupValue: _selected,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(reason),
                onChanged: (v) => setState(() => _selected = v),
              ),
            ),
            if (_selected == 'Other')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'Describe the reason',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _resolvedReason ?? ''),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

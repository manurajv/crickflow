import 'package:flutter/material.dart';

import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../../../../core/theme/cf_colors.dart';

/// Required when an over ends with a different legal-ball count than configured.
class ManualOverNoteDialog extends StatefulWidget {
  const ManualOverNoteDialog({
    super.key,
    required this.expectedBalls,
    required this.actualBalls,
  });

  final int expectedBalls;
  final int actualBalls;

  static const quickReasons = [
    'Umpire called over early',
    'Umpire counted extra ball',
    'Local tournament rule',
    'Scoring correction',
    'Other',
  ];

  static Future<String?> show(
    BuildContext context, {
    required int expectedBalls,
    required int actualBalls,
  }) {
    return ScoringUiKit.showSheet<String>(
      context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (ctx) => ManualOverNoteDialog(
        expectedBalls: expectedBalls,
        actualBalls: actualBalls,
      ),
    );
  }

  @override
  State<ManualOverNoteDialog> createState() => _ManualOverNoteDialogState();
}

class _ManualOverNoteDialogState extends State<ManualOverNoteDialog> {
  String? _selected;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String? get _resolvedReason {
    if (_selected == null) return null;
    if (_selected == 'Other') {
      final custom = _customController.text.trim();
      return custom.isEmpty ? null : custom;
    }
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.card,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Over adjustment note'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Expected ${widget.expectedBalls} legal balls, '
                'actual ${widget.actualBalls}.\n\n'
                'Why was the over ended manually?',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: cf.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...ManualOverNoteDialog.quickReasons.map(
              (reason) => RadioListTile<String>(
                value: reason,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                dense: true,
                activeColor: cf.accent,
              ),
            ),
            if (_selected == 'Other')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _customController,
                  decoration: const InputDecoration(
                    labelText: 'Custom note',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FilledButton(
                onPressed: _resolvedReason == null
                    ? null
                    : () => Navigator.pop(context, _resolvedReason),
                style: ScoringUiKit.primaryButtonStyle(context),
                child: const Text(
                  'Confirm',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

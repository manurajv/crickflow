import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

/// User selection from the Change Batters sheet.
class ChangeBattersResult {
  const ChangeBattersResult({
    required this.reason,
    this.note,
    this.swapEnds = true,
    this.runsCancelled,
  });

  final BatterSwapReason reason;
  final String? note;
  final bool swapEnds;
  final int? runsCancelled;
}

Future<ChangeBattersResult?> showChangeBattersSheet(BuildContext context) {
  return ScoringUiKit.showDraggableSheet<ChangeBattersResult>(
    context,
    initialChildSize: 0.55,
    minChildSize: 0.4,
    maxChildSize: 0.85,
    builder: (ctx, controller) => ChangeBattersSheet(
      scrollController: controller,
    ),
  );
}

class ChangeBattersSheet extends StatefulWidget {
  const ChangeBattersSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<ChangeBattersSheet> createState() => _ChangeBattersSheetState();
}

class _ChangeBattersSheetState extends State<ChangeBattersSheet> {
  BatterSwapReason? _pendingReason;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _needsNote =>
      _pendingReason == BatterSwapReason.umpireCorrection ||
      _pendingReason == BatterSwapReason.other;

  void _select(BatterSwapReason reason) {
    if (reason == BatterSwapReason.shortRun) {
      Navigator.pop(
        context,
        const ChangeBattersResult(
          reason: BatterSwapReason.shortRun,
          swapEnds: false,
          runsCancelled: 1,
        ),
      );
      return;
    }
    if (reason == BatterSwapReason.manual ||
        reason == BatterSwapReason.crossedBeforeWicket) {
      Navigator.pop(
        context,
        ChangeBattersResult(reason: reason),
      );
      return;
    }
    setState(() => _pendingReason = reason);
  }

  void _confirmWithNote() {
    final reason = _pendingReason;
    if (reason == null) return;
    Navigator.pop(
      context,
      ChangeBattersResult(
        reason: reason,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          const ScoringSheetHeader(title: 'Change Batters'),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              children: [
                _OptionTile(
                  icon: Icons.swap_horiz,
                  label: 'Swap Striker & Non-Striker',
                  onTap: () => _select(BatterSwapReason.manual),
                ),
                _OptionTile(
                  icon: Icons.short_text,
                  label: 'Short Run',
                  subtitle: 'Cancel 1 run (umpire signal)',
                  onTap: () => _select(BatterSwapReason.shortRun),
                ),
                _OptionTile(
                  icon: Icons.directions_run,
                  label: 'Batters Crossed Before Wicket',
                  onTap: () => _select(BatterSwapReason.crossedBeforeWicket),
                ),
                _OptionTile(
                  icon: Icons.gavel_outlined,
                  label: 'Umpire Correction',
                  onTap: () => _select(BatterSwapReason.umpireCorrection),
                ),
                _OptionTile(
                  icon: Icons.edit_note,
                  label: 'Other Scoring Adjustment',
                  onTap: () => _select(BatterSwapReason.other),
                ),
                if (_needsNote) ...[
                  const SizedBox(height: AppDimens.spaceMd),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Scorer note (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  FilledButton(
                    onPressed: _confirmWithNote,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.gold),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

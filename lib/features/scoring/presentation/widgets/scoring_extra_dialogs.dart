import 'package:flutter/material.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../domain/services/scoring_engine.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

/// Wide / no-ball / bye / leg-bye / running runs (reference-style).
class ScoringExtraDialogs {
  ScoringExtraDialogs._();

  static Future<BallEventInput?> showWide(
    BuildContext context, {
    required MatchRulesModel rules,
  }) {
    return _showExtraGrid(
      context,
      title: 'Wide ball (WD=${rules.wideRuns})',
      prefix: 'WD',
      onSelect: (extra) => BallEventInput(type: BallEventType.wide, runs: extra),
    );
  }

  static Future<BallEventInput?> showNoBall(
    BuildContext context, {
    required MatchRulesModel rules,
  }) {
    return ScoringUiKit.showSheet<BallEventInput>(
      context,
      builder: (ctx) => _NoBallSheet(rules: rules),
    );
  }

  static Future<BallEventInput?> showBye(BuildContext context) {
    return _showRunPickerSheet(
      context,
      title: 'Bye runs',
      onSelect: (runs) => BallEventInput(type: BallEventType.bye, runs: runs),
      footer: _SetKeeperFooter(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Set keeper — coming soon')),
          );
        },
      ),
    );
  }

  static Future<BallEventInput?> showLegBye(BuildContext context) {
    return _showRunPickerSheet(
      context,
      title: 'Leg bye runs',
      onSelect: (runs) =>
          BallEventInput(type: BallEventType.legBye, runs: runs),
    );
  }

  /// 5 / 7 — runs scored by running (bottom sheet).
  static Future<void> showRunningRuns(
    BuildContext context, {
    required void Function(int runs) onRun,
  }) async {
    final runs = await _showRunningRunsSheet(context);
    if (runs != null) {
      onRun(runs);
    }
  }

  static Future<int?> _showRunningRunsSheet(BuildContext context) {
    return ScoringUiKit.showSheet<int>(
      context,
      builder: (ctx) {
        final width = MediaQuery.sizeOf(ctx).width;
        final hPad = AppDimens.spaceMd;
        final gap = 10.0;
        final cellW = (width - hPad * 2 - gap * 4) / 5;
        final cellH = cellW;
        final bigH = cellH * 1.1;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoringSheetHeader(title: 'Runs scored by running'),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: bigH,
                        child: ScoringGridButton(
                          label: '5',
                          onTap: () => Navigator.pop(ctx, 5),
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: SizedBox(
                        height: bigH,
                        child: ScoringGridButton(
                          label: '7',
                          onTap: () => Navigator.pop(ctx, 7),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: gap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 4; i++) ...[
                      if (i > 1) SizedBox(width: gap),
                      SizedBox(
                        width: cellW,
                        height: cellH,
                        child: ScoringGridButton(
                          label: '$i',
                          onTap: () => Navigator.pop(ctx, i),
                        ),
                      ),
                    ],
                    SizedBox(width: gap),
                    SizedBox(
                      width: cellW,
                      height: cellH,
                      child: ScoringGridButton(
                        label: '+',
                        onTap: () async {
                          final extra = await _showCustomRuns(ctx);
                          if (extra != null && ctx.mounted) {
                            Navigator.pop(ctx, extra);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceSm),
                const Text(
                  '4 and 6 count as runs, not boundaries.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<BallEventInput?> _showRunPickerSheet(
    BuildContext context, {
    required String title,
    required BallEventInput Function(int runs) onSelect,
    Widget? footer,
  }) {
    return ScoringUiKit.showSheet<BallEventInput>(
      context,
      builder: (ctx) {
        final width = MediaQuery.sizeOf(ctx).width;
        final hPad = AppDimens.spaceMd;
        final gap = 10.0;
        final cellW = (width - hPad * 2 - gap * 4) / 5;
        final cellH = cellW;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoringSheetHeader(title: title),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 4; i++) ...[
                      if (i > 1) SizedBox(width: gap),
                      SizedBox(
                        width: cellW,
                        height: cellH,
                        child: ScoringGridButton(
                          label: '$i',
                          onTap: () => Navigator.pop(ctx, onSelect(i)),
                        ),
                      ),
                    ],
                    SizedBox(width: gap),
                    SizedBox(
                      width: cellW,
                      height: cellH,
                      child: ScoringGridButton(
                        label: '+',
                        onTap: () async {
                          final extra = await _showCustomRuns(ctx);
                          if (extra != null && ctx.mounted) {
                            Navigator.pop(ctx, onSelect(extra));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (footer != null) ...[
                  const SizedBox(height: AppDimens.spaceMd),
                  footer,
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<BallEventInput?> _showExtraGrid(
    BuildContext context, {
    required String title,
    required String prefix,
    required BallEventInput Function(int extraRuns) onSelect,
  }) {
    return ScoringUiKit.showSheet<BallEventInput>(
      context,
      builder: (ctx) {
        final width = MediaQuery.sizeOf(ctx).width;
        final hPad = AppDimens.spaceMd;
        final gap = 8.0;
        final cellW = (width - hPad * 2 - gap * 3) / 4;
        final cellH = cellW * 0.72;

        Widget gridCell(String label, int extra) {
          return SizedBox(
            width: cellW,
            height: cellH,
            child: ScoringGridButton(
              label: label,
              onTap: () => Navigator.pop(ctx, onSelect(extra)),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoringSheetHeader(
                  title: title,
                  trailing: IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.pop(ctx),
                    tooltip: 'Close',
                  ),
                ),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i <= 6; i++)
                      gridCell('$prefix + $i', i),
                    SizedBox(
                      width: cellW,
                      height: cellH,
                      child: ScoringGridButton(
                        label: '+',
                        onTap: () async {
                          final extra = await _showCustomRuns(ctx);
                          if (extra != null && ctx.mounted) {
                            Navigator.pop(ctx, onSelect(extra));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

Future<int?> _showCustomRuns(BuildContext context) {
  var runs = 1;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Runs'),
        content: SizedBox(
          width: 72,
          child: TextField(
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofocus: true,
            decoration: const InputDecoration(isDense: true, hintText: '1'),
            onChanged: (v) => setState(() => runs = int.tryParse(v) ?? 1),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, runs.clamp(0, 12)),
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

/// Reference-style: title, numeric field, note, Cancel / Ok.
class _RunningRunsInputSheet extends StatefulWidget {
  const _RunningRunsInputSheet();

  @override
  State<_RunningRunsInputSheet> createState() => _RunningRunsInputSheetState();
}

class _RunningRunsInputSheetState extends State<_RunningRunsInputSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final runs = int.tryParse(_controller.text.trim());
    if (runs == null || runs < 0) return;
    Navigator.pop(context, runs.clamp(0, 12));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          0,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScoringSheetHeader(title: 'Runs scored by running'),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            const Text(
              '*4 and 6 will not be considered boundaries.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Ok'),
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

class _NoBallSheet extends StatefulWidget {
  const _NoBallSheet({required this.rules});

  final MatchRulesModel rules;

  @override
  State<_NoBallSheet> createState() => _NoBallSheetState();
}

class _NoBallSheetState extends State<_NoBallSheet> {
  NoBallRunsMode _mode = NoBallRunsMode.bat;
  int? _selectedRuns;

  void _pick(int runs) {
    setState(() => _selectedRuns = runs);
    Navigator.pop(
      context,
      BallEventInput(
        type: BallEventType.noBall,
        runs: runs,
        noBallRunsMode: _mode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = AppDimens.spaceMd;
    final gap = 8.0;
    final cellW = (width - hPad * 2 - gap * 3) / 4;
    final cellH = cellW * 0.72;
    final nb = widget.rules.noBallRuns;

    Widget gridCell(String label, int extra) {
      return SizedBox(
        width: cellW,
        height: cellH,
        child: ScoringGridButton(
          label: label,
          selected: _selectedRuns == extra,
          onTap: () => _pick(extra),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  child: Row(
                    children: [
                      const Expanded(child: _HeaderLine()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No ball',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              ' (NB=$nb)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Flexible(child: _HeaderLine()),
                            IconButton(
                              icon: const Icon(Icons.settings_outlined, size: 20),
                              color: AppColors.textMuted,
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
              ],
            ),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i <= 6; i++) gridCell('NB + $i', i),
                SizedBox(
                  width: cellW,
                  height: cellH,
                  child: ScoringGridButton(
                    label: '+',
                    onTap: () async {
                      final extra = await _showCustomRuns(context);
                      if (extra != null && mounted) _pick(extra);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NoBallModeOption(
                  label: 'From bat',
                  selected: _mode == NoBallRunsMode.bat,
                  onTap: () => setState(() => _mode = NoBallRunsMode.bat),
                ),
                _NoBallModeOption(
                  label: 'Bye',
                  selected: _mode == NoBallRunsMode.bye,
                  onTap: () => setState(() => _mode = NoBallRunsMode.bye),
                ),
                _NoBallModeOption(
                  label: 'Leg bye',
                  selected: _mode == NoBallRunsMode.legBye,
                  onTap: () => setState(() => _mode = NoBallRunsMode.legBye),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.border);
  }
}

class _NoBallModeOption extends StatelessWidget {
  const _NoBallModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.gold : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetKeeperFooter extends StatelessWidget {
  const _SetKeeperFooter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                'WK',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Set keeper',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


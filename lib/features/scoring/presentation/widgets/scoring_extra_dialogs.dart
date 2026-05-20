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

  /// Opens no-ball details (runs grid + how runs were scored). Always use for NB.
  static Future<BallEventInput?> showNoBall(
    BuildContext context, {
    required MatchRulesModel rules,
    int? additionalRuns,
  }) {
    return showNoBallDetails(
      context,
      rules: rules,
      additionalRuns: additionalRuns,
    );
  }

  static Future<BallEventInput?> showNoBallDetails(
    BuildContext context, {
    required MatchRulesModel rules,
    int? additionalRuns,
  }) {
    return ScoringUiKit.showSheet<BallEventInput>(
      context,
      isScrollControlled: true,
      builder: (ctx) => _NoBallDetailsSheet(
        rules: rules,
        additionalRuns: additionalRuns,
      ),
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

/// No-ball runs grid + mandatory "how runs were scored" type (reference flow).
class _NoBallDetailsSheet extends StatefulWidget {
  const _NoBallDetailsSheet({
    required this.rules,
    this.additionalRuns,
  });

  final MatchRulesModel rules;
  final int? additionalRuns;

  @override
  State<_NoBallDetailsSheet> createState() => _NoBallDetailsSheetState();
}

class _NoBallDetailsSheetState extends State<_NoBallDetailsSheet> {
  int? _selectedRuns;

  @override
  void initState() {
    super.initState();
    final preset = widget.additionalRuns;
    if (preset != null && preset > 0) {
      _selectedRuns = preset;
    }
  }

  bool get _needsRunType => (_selectedRuns ?? 0) > 0;

  void _commit(int additionalRuns, NoBallRunsMode mode) {
    Navigator.pop(
      context,
      BallEventInput(
        type: BallEventType.noBall,
        runs: additionalRuns,
        noBallRunsMode: mode,
      ),
    );
  }

  void _onRunsPicked(int additional) {
    if (additional == 0) {
      _commit(0, NoBallRunsMode.bat);
      return;
    }
    setState(() => _selectedRuns = additional);
  }

  void _onRunTypePicked(NoBallRunsMode mode) {
    final runs = _selectedRuns;
    if (runs == null || runs <= 0) return;
    _commit(runs, mode);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = AppDimens.spaceMd;
    final gap = 8.0;
    final cellW = (width - hPad * 2 - gap * 3) / 4;
    final cellH = cellW * 0.72;
    final nb = widget.rules.noBallRuns;

    Widget gridCell(String label, int additional) {
      return SizedBox(
        width: cellW,
        height: cellH,
        child: ScoringGridButton(
          label: label,
          selected: _selectedRuns == additional,
          onTap: () => _onRunsPicked(additional),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScoringSheetHeader(
              title: 'No ball (NB=$nb)',
              trailing: IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                color: AppColors.textMuted,
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
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
                      if (extra != null && mounted) _onRunsPicked(extra);
                    },
                  ),
                ),
              ],
            ),
            if (_needsRunType) ...[
              const SizedBox(height: AppDimens.spaceMd),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppDimens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: _NoBallRunTypeChip(
                      label: 'From bat',
                      onTap: () => _onRunTypePicked(NoBallRunsMode.bat),
                    ),
                  ),
                  Expanded(
                    child: _NoBallRunTypeChip(
                      label: 'Bye',
                      onTap: () => _onRunTypePicked(NoBallRunsMode.bye),
                    ),
                  ),
                  Expanded(
                    child: _NoBallRunTypeChip(
                      label: 'Leg bye',
                      onTap: () => _onRunTypePicked(NoBallRunsMode.legBye),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal run-type choice (reference: From bat · Bye · Leg bye).
class _NoBallRunTypeChip extends StatelessWidget {
  const _NoBallRunTypeChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: selected ? AppColors.gold : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
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


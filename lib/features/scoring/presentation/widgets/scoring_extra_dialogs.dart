import 'package:flutter/material.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../domain/services/scoring_engine.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../../../../core/theme/cf_colors.dart';

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
        final cf = ctx.cf;
        const hPad = AppDimens.spaceMd;
        const gap = 10.0;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoringSheetHeader(title: 'Runs scored by running'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellW =
                        ((constraints.maxWidth - gap * 4) / 5).clamp(0.0, 120.0);
                    final cellH = cellW;
                    final bigH = cellH * 1.1;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                            const SizedBox(width: gap),
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
                        const SizedBox(height: gap),
                        Row(
                          children: [
                            for (var i = 1; i <= 4; i++) ...[
                              if (i > 1) const SizedBox(width: gap),
                              Expanded(
                                child: SizedBox(
                                  height: cellH,
                                  child: ScoringGridButton(
                                    label: '$i',
                                    onTap: () => Navigator.pop(ctx, i),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: gap),
                            Expanded(
                              child: SizedBox(
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
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  '4 and 6 count as runs, not boundaries.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: cf.textMuted,
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
        const hPad = AppDimens.spaceMd;
        const gap = 10.0;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoringSheetHeader(title: title),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellH =
                        ((constraints.maxWidth - gap * 4) / 5).clamp(0.0, 120.0);
                    return Row(
                      children: [
                        for (var i = 1; i <= 4; i++) ...[
                          if (i > 1) const SizedBox(width: gap),
                          Expanded(
                            child: SizedBox(
                              height: cellH,
                              child: ScoringGridButton(
                                label: '$i',
                                onTap: () =>
                                    Navigator.pop(ctx, onSelect(i)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: gap),
                        Expanded(
                          child: SizedBox(
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
                        ),
                      ],
                    );
                  },
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
        final cf = ctx.cf;
        const hPad = AppDimens.spaceMd;
        const gap = 8.0;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoringSheetHeader(
                  title: title,
                  trailing: IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    color: cf.textMuted,
                    onPressed: () => Navigator.pop(ctx),
                    tooltip: 'Close',
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellW =
                        ((constraints.maxWidth - gap * 3) / 4).clamp(0.0, 140.0);
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

                    return Wrap(
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
                    );
                  },
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
  return ScoringUiKit.showSheet<int>(
    context,
    isScrollControlled: true,
    builder: (ctx) {
      final cf = ctx.cf;
      return StatefulBuilder(
        builder: (innerCtx, setState) => Material(
        color: cf.surface,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            0,
            AppDimens.spaceMd,
            MediaQuery.paddingOf(ctx).bottom + AppDimens.spaceMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScoringSheetHeader(
                title: 'Runs',
                trailing: ScoringUiKit.sheetCloseButton(ctx),
              ),
              TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '1',
                  filled: true,
                  fillColor: cf.sectionBackground,
                ),
                onChanged: (v) => setState(() => runs = int.tryParse(v) ?? 1),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, runs.clamp(0, 12)),
                style: ScoringUiKit.primaryButtonStyle(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
      );
    },
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
    final cf = context.cf;
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: cf.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: cf.card,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cf.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cf.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: cf.accent, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text(
              '*4 and 6 will not be considered boundaries.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: cf.textMuted,
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
                      foregroundColor: cf.textSecondary,
                      side: BorderSide(color: cf.border),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: ScoringUiKit.primaryButtonStyle(context),
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
    final cf = context.cf;
    const hPad = AppDimens.spaceMd;
    const gap = 8.0;
    final nb = widget.rules.noBallRuns;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(hPad, 0, hPad, AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScoringSheetHeader(
              title: 'No ball (NB=$nb)',
              trailing: IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                color: cf.textMuted,
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final cellW =
                    ((constraints.maxWidth - gap * 3) / 4).clamp(0.0, 140.0);
                final cellH = cellW * 0.72;

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

                return Wrap(
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
                );
              },
            ),
            if (_needsRunType) ...[
              const SizedBox(height: AppDimens.spaceMd),
              Divider(height: 1, color: cf.border),
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
    final cf = context.cf;
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
                color: selected ? cf.accent : cf.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? cf.textPrimary
                      : cf.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


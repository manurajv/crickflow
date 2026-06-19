import 'dart:math' show max;

import 'package:flutter/material.dart';
import '../../../../core/theme/cf_colors.dart';
import 'scoring_extra_dialogs.dart';

/// Extras row (bottom) + left column (UNDO / 5,7 / OUT) + run grid (0–6).
/// Run rows are 1.5× the height of side keys; equal column width.
class LiveScoringKeypad extends StatelessWidget {
  const LiveScoringKeypad({
    super.key,
    required this.height,
    required this.onRun,
    required this.onWide,
    required this.onNoBall,
    required this.onBye,
    required this.onLegBye,
    required this.onOut,
    required this.onUndo,
    required this.isBusy,
  });

  final double height;
  final void Function(int runs) onRun;
  final VoidCallback onWide;
  final VoidCallback onNoBall;
  final VoidCallback onBye;
  final VoidCallback onLegBye;
  final VoidCallback onOut;
  final VoidCallback onUndo;
  final bool isBusy;

  static const _cols = 4;
  static const _gap = 1.0;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final busyH = isBusy ? 3.0 : 0.0;
    final totalH = max(0.0, height);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (totalH < 1) {
          return ColoredBox(color: cf.card);
        }

        final colW =
            (constraints.maxWidth - _gap * (_cols + 1)) / _cols;
        final bodyH = totalH - busyH;
        var extrasH = (bodyH * 0.18).clamp(24.0, 44.0);
        if (extrasH > bodyH * 0.45) {
          extrasH = bodyH * 0.35;
        }
        final mainH = max(0.0, bodyH - extrasH - _gap);
        final sideKeyH = mainH > _gap * 2
            ? max(20.0, (mainH - _gap * 2) / 3)
            : 0.0;
        final runRowH = sideKeyH * 1.5;

        Widget cell({
          required String label,
          required VoidCallback onTap,
          required double w,
          required double h,
          Color? accent,
          bool bold = false,
          String? sublabel,
          double labelSize = 22,
        }) {
          return SizedBox(
            width: w,
            height: h,
            child: _Key(
              label: label,
              onTap: onTap,
              accent: accent,
              bold: bold,
              sublabel: sublabel,
              fontSize: labelSize,
            ),
          );
        }

        if (mainH < 20) {
          return ColoredBox(
            color: cf.card,
            child: SizedBox(height: totalH),
          );
        }

        return ColoredBox(
          color: cf.card,
          child: SizedBox(
            height: totalH,
            child: Column(
              children: [
                SizedBox(
                  height: mainH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: _gap),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: runRowH,
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  cell(
                                    label: '0',
                                    onTap: () => onRun(0),
                                    w: colW,
                                    h: runRowH,
                                  ),
                                  SizedBox(width: _gap),
                                  cell(
                                    label: '1',
                                    onTap: () => onRun(1),
                                    w: colW,
                                    h: runRowH,
                                  ),
                                  SizedBox(width: _gap),
                                  cell(
                                    label: '2',
                                    onTap: () => onRun(2),
                                    w: colW,
                                    h: runRowH,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: _gap),
                            SizedBox(
                              height: runRowH,
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  cell(
                                    label: '3',
                                    onTap: () => onRun(3),
                                    w: colW,
                                    h: runRowH,
                                  ),
                                  SizedBox(width: _gap),
                                  cell(
                                    label: '4',
                                    onTap: () => onRun(4),
                                    w: colW,
                                    h: runRowH,
                                    accent: cf.accent,
                                    sublabel: 'Four',
                                  ),
                                  SizedBox(width: _gap),
                                  cell(
                                    label: '6',
                                    onTap: () => onRun(6),
                                    w: colW,
                                    h: runRowH,
                                    accent: cf.isLight
                                        ? cf.scoreEmphasis
                                        : CfColors.goldDark,
                                    sublabel: 'Six',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: _gap),
                      SizedBox(
                        width: colW,
                        child: Column(
                          children: [
                            Expanded(
                              child: _Key(
                                label: 'UNDO',
                                onTap: onUndo,
                                accent: cf.accent,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: _gap),
                            Expanded(
                              child: _Key(
                                label: '5, 7',
                                onTap: () =>
                                    ScoringExtraDialogs.showRunningRuns(
                                  context,
                                  onRun: onRun,
                                ),
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: _gap),
                            Expanded(
                              child: _Key(
                                label: 'OUT',
                                onTap: onOut,
                                accent: cf.error,
                                bold: true,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: _gap),
                    ],
                  ),
                ),
                SizedBox(height: _gap),
                SizedBox(
                  height: extrasH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: _gap),
                      cell(
                        label: 'WD',
                        onTap: onWide,
                        w: colW,
                        h: extrasH,
                        labelSize: 14,
                      ),
                      SizedBox(width: _gap),
                      cell(
                        label: 'NB',
                        onTap: onNoBall,
                        w: colW,
                        h: extrasH,
                        labelSize: 14,
                      ),
                      SizedBox(width: _gap),
                      cell(
                        label: 'BYE',
                        onTap: onBye,
                        w: colW,
                        h: extrasH,
                        labelSize: 14,
                      ),
                      SizedBox(width: _gap),
                      cell(
                        label: 'LB',
                        onTap: onLegBye,
                        w: colW,
                        h: extrasH,
                        labelSize: 14,
                      ),
                      SizedBox(width: _gap),
                    ],
                  ),
                ),
                if (isBusy)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: cf.accent,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    this.fontSize = 22,
    this.sublabel,
    this.accent,
    this.bold = false,
  });

  final String label;
  final VoidCallback onTap;
  final double fontSize;
  final String? sublabel;
  final Color? accent;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: cf.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: sublabel == null
                  ? Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight:
                            bold ? FontWeight.w800 : FontWeight.w700,
                        color: accent ?? cf.textPrimary,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w700,
                            color: accent ?? cf.textPrimary,
                          ),
                        ),
                        Text(
                          sublabel!,
                          style: TextStyle(
                            fontSize: 9,
                            color: cf.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Extras row + left column (UNDO / 5,7 / OUT) + run grid (0–6).
/// Run rows are 1.5× the height of side keys; all keys share the same width.
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
  static const _runRowMultiplier = 1.5;

  @override
  Widget build(BuildContext context) {
    final bodyH = height - (isBusy ? 3.0 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final colW =
            (constraints.maxWidth - _gap * (_cols + 1)) / _cols;
        final extrasH = (bodyH * 0.22).clamp(36.0, 48.0);
        final mainH = bodyH - extrasH - _gap * 2;
        final sideKeyH = (mainH - _gap * 2) / 3;
        final runRowH = sideKeyH * _runRowMultiplier;

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

        Widget gapW() => SizedBox(width: _gap);
        Widget gapH() => SizedBox(height: _gap);

        Widget extrasRow() {
          return SizedBox(
            height: extrasH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                gapW(),
                cell(label: 'WD', onTap: onWide, w: colW, h: extrasH, labelSize: 14),
                gapW(),
                cell(label: 'NB', onTap: onNoBall, w: colW, h: extrasH, labelSize: 14),
                gapW(),
                cell(label: 'BYE', onTap: onBye, w: colW, h: extrasH, labelSize: 14),
                gapW(),
                cell(label: 'LB', onTap: onLegBye, w: colW, h: extrasH, labelSize: 14),
                gapW(),
              ],
            ),
          );
        }

        return ColoredBox(
          color: AppColors.card,
          child: SizedBox(
            height: bodyH,
            child: Column(
              children: [
                gapH(),
                extrasRow(),
                gapH(),
                SizedBox(
                  height: mainH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      gapW(),
                      SizedBox(
                        width: colW,
                        child: Column(
                          children: [
                            cell(
                              label: 'UNDO',
                              onTap: onUndo,
                              w: colW,
                              h: sideKeyH,
                              accent: AppColors.gold,
                              labelSize: 13,
                            ),
                            gapH(),
                            cell(
                              label: '5, 7',
                              onTap: () => _showOddRuns(context),
                              w: colW,
                              h: sideKeyH,
                              labelSize: 13,
                            ),
                            gapH(),
                            cell(
                              label: 'OUT',
                              onTap: onOut,
                              w: colW,
                              h: sideKeyH,
                              accent: AppColors.accentRed,
                              bold: true,
                              labelSize: 14,
                            ),
                          ],
                        ),
                      ),
                      gapW(),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: runRowH,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  cell(
                                    label: '0',
                                    onTap: () => onRun(0),
                                    w: colW,
                                    h: runRowH,
                                  ),
                                  gapW(),
                                  cell(
                                    label: '1',
                                    onTap: () => onRun(1),
                                    w: colW,
                                    h: runRowH,
                                  ),
                                  gapW(),
                                  cell(
                                    label: '2',
                                    onTap: () => onRun(2),
                                    w: colW,
                                    h: runRowH,
                                  ),
                                ],
                              ),
                            ),
                            gapH(),
                            SizedBox(
                              height: runRowH,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  cell(
                                    label: '3',
                                    onTap: () => onRun(3),
                                    w: colW,
                                    h: runRowH,
                                  ),
                                  gapW(),
                                  cell(
                                    label: '4',
                                    onTap: () => onRun(4),
                                    w: colW,
                                    h: runRowH,
                                    accent: AppColors.primaryBlue,
                                    sublabel: 'Four',
                                  ),
                                  gapW(),
                                  cell(
                                    label: '6',
                                    onTap: () => onRun(6),
                                    w: colW,
                                    h: runRowH,
                                    accent: AppColors.goldDark,
                                    sublabel: 'Six',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      gapW(),
                    ],
                  ),
                ),
                if (isBusy)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primaryBlue,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOddRuns(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onRun(5);
                },
                child: const Text('5 runs'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onRun(7);
                },
                child: const Text('7 runs'),
              ),
            ],
          ),
        ),
      ),
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
    return Material(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: AppColors.border),
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
                        color: accent ?? AppColors.textPrimary,
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
                            color: accent ?? AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          sublabel!,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textMuted,
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

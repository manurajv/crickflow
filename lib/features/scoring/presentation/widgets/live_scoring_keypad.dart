import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

/// Reference-style keypad: extras + undo/out on the left, runs on the right.
class LiveScoringKeypad extends StatelessWidget {
  const LiveScoringKeypad({
    super.key,
    required this.onRun,
    required this.onWide,
    required this.onNoBall,
    required this.onBye,
    required this.onLegBye,
    required this.onOut,
    required this.onUndo,
    required this.isBusy,
  });

  final void Function(int runs) onRun;
  final VoidCallback onWide;
  final VoidCallback onNoBall;
  final VoidCallback onBye;
  final VoidCallback onLegBye;
  final VoidCallback onOut;
  final VoidCallback onUndo;
  final bool isBusy;

  static const _keyBg = Color(0xFFFFFFFF);
  static const _panelBg = Color(0xFFF0F2F5);
  static const _border = Color(0xFFE0E4EA);
  static const _textDark = Color(0xFF263238);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _panelBg,
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _LeftKey('WD', onTap: onWide),
                      ),
                      Expanded(
                        child: _LeftKey('NB', onTap: onNoBall),
                      ),
                      Expanded(
                        child: _LeftKey('BYE', onTap: onBye),
                      ),
                      Expanded(
                        child: _LeftKey('LB', onTap: onLegBye),
                      ),
                      Expanded(
                        child: _LeftKey(
                          'UNDO',
                          accent: AppColors.primaryBlue,
                          onTap: onUndo,
                        ),
                      ),
                      Expanded(
                        child: _LeftKey(
                          '5, 7',
                          onTap: () => _showOddRuns(context),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _LeftKey(
                          'OUT',
                          accent: AppColors.accentRed,
                          bold: true,
                          onTap: onOut,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _RunKey('0', onTap: () => onRun(0)),
                            _RunKey('1', onTap: () => onRun(1)),
                            _RunKey('2', onTap: () => onRun(2)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _RunKey('3', onTap: () => onRun(3)),
                            _RunKey('4', sublabel: 'Four', onTap: () => onRun(4)),
                            _RunKey('6', sublabel: 'Six', onTap: () => onRun(6)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primaryBlue,
              ),
            ),
        ],
      ),
    );
  }

  void _showOddRuns(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onRun(5);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
                child: const Text('5 runs'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onRun(7);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
                child: const Text('7 runs'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunKey extends StatelessWidget {
  const _RunKey(
    this.value, {
    this.sublabel,
    required this.onTap,
  });

  final String value;
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFour = value == '4';
    final isSix = value == '6';

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: LiveScoringKeypad._keyBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: LiveScoringKeypad._border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: isSix
                          ? AppColors.goldDark
                          : isFour
                              ? AppColors.primaryBlue
                              : LiveScoringKeypad._textDark,
                    ),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF78909C),
                        fontWeight: FontWeight.w500,
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

class _LeftKey extends StatelessWidget {
  const _LeftKey(
    this.label, {
    this.accent,
    this.bold = false,
    required this.onTap,
  });

  final String label;
  final Color? accent;
  final bool bold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: LiveScoringKeypad._keyBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: LiveScoringKeypad._border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: bold ? 17 : label.length <= 3 ? 15 : 12,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: accent ?? LiveScoringKeypad._textDark,
                letterSpacing: label == 'UNDO' ? 0.5 : 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

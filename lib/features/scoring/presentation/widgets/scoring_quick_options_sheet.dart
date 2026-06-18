import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

/// Quick-settings shortcuts during live scoring (two rows + show more).
class ScoringQuickOptionsSheet extends StatefulWidget {
  const ScoringQuickOptionsSheet({
    super.key,
    required this.onEditLineup,
    required this.onChangeWicketkeeper,
    required this.onChangeBowler,
    required this.onEndInnings,
    required this.onEndOver,
    required this.onScorecard,
    required this.onMatchRules,
    this.onReviseTarget,
    this.onEditToss,
    this.onChangeScorer,
  });

  final VoidCallback onEditLineup;
  final VoidCallback onChangeWicketkeeper;
  final VoidCallback onChangeBowler;
  final VoidCallback onEndInnings;
  final VoidCallback onEndOver;
  final VoidCallback onScorecard;
  final VoidCallback onMatchRules;
  final VoidCallback? onReviseTarget;
  final VoidCallback? onEditToss;
  final VoidCallback? onChangeScorer;

  @override
  State<ScoringQuickOptionsSheet> createState() =>
      _ScoringQuickOptionsSheetState();
}

class _ScoringQuickOptionsSheetState extends State<ScoringQuickOptionsSheet> {
  static const _crossAxisCount = 4;
  static const _defaultRows = 2;
  static const _defaultVisibleCount = _crossAxisCount * _defaultRows;

  bool _expanded = false;

  List<_Shortcut> get _shortcuts => [
        const _Shortcut(Icons.help_outline, 'Need Help', _noop),
        _Shortcut(Icons.rule_outlined, 'Match Rules', widget.onMatchRules),
        if (widget.onChangeScorer != null)
          _Shortcut(Icons.swap_horiz, 'Change Scorer', widget.onChangeScorer!)
        else
          const _Shortcut(Icons.swap_horiz, 'Change Scorer', _noop),
        _Shortcut(Icons.group_outlined, 'Change Squad', widget.onEditLineup),
        _Shortcut(
          Icons.assignment_outlined,
          'Full Scorecard',
          widget.onScorecard,
        ),
        _Shortcut(Icons.stop_circle_outlined, 'End Over', widget.onEndOver),
        _Shortcut(
          Icons.sports_handball_outlined,
          'Change Keeper',
          widget.onChangeWicketkeeper,
        ),
        _Shortcut(
          Icons.sports_baseball_outlined,
          'Change Bowler',
          widget.onChangeBowler,
        ),
        const _Shortcut(Icons.bolt_outlined, 'Power Play', _noop),
        if (widget.onReviseTarget != null)
          _Shortcut(Icons.calculate_outlined, 'Revise Target', widget.onReviseTarget!)
        else
          const _Shortcut(Icons.calculate_outlined, 'Revise Target', _noop),
        const _Shortcut(Icons.schedule_outlined, 'Match Breaks', _noop),
        if (widget.onEditToss != null)
          _Shortcut(
            Icons.monetization_on_outlined,
            'Change Toss',
            widget.onEditToss!,
          ),
        _Shortcut(Icons.flag_outlined, 'End Innings', widget.onEndInnings),
      ];

  bool get _hasMoreOptions => _shortcuts.length > _defaultVisibleCount;

  int get _visibleCount => _expanded
      ? _shortcuts.length
      : _defaultVisibleCount.clamp(0, _shortcuts.length);

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final maxGridHeight = MediaQuery.sizeOf(context).height * 0.5;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScoringSheetHeader(
              title: 'Select a shortcut',
              mutedTitle: true,
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxGridHeight),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: _expanded
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _visibleCount,
                  itemBuilder: (context, i) {
                    final shortcut = _shortcuts[i];
                    return ScoringShortcutTile(
                      icon: shortcut.icon,
                      label: shortcut.label,
                      onTap: () {
                        Navigator.pop(context);
                        shortcut.onTap();
                      },
                    );
                  },
                ),
              ),
            ),
            if (_hasMoreOptions)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show less' : 'Show more',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut {
  const _Shortcut(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

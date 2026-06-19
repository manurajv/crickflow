import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

/// Match break type picker (grid) from quick shortcuts.
class MatchBreaksSheet extends ConsumerStatefulWidget {
  const MatchBreaksSheet({super.key, required this.match});

  final MatchModel match;

  static Future<void> show(BuildContext context, MatchModel match) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      builder: (_) => MatchBreaksSheet(match: match),
    );
  }

  @override
  ConsumerState<MatchBreaksSheet> createState() => _MatchBreaksSheetState();
}

class _MatchBreaksSheetState extends ConsumerState<MatchBreaksSheet> {
  var _starting = false;

  static const _types = [
    _BreakType('Drinks', Icons.local_drink_outlined),
    _BreakType('Timed Out', Icons.timer_off_outlined),
    _BreakType('Lunch', Icons.restaurant_outlined),
    _BreakType('Stumps', Icons.nightlight_outlined),
    _BreakType('Rain', Icons.water_drop_outlined),
    _BreakType('Other', Icons.more_horiz),
  ];

  Future<String?> _promptReason(String breakType) async {
    final ctrl = TextEditingController();
    final result = await ScoringUiKit.showThemedDialog<String>(
      context,
      builder: (ctx) => AlertDialog(
        title: Text('$breakType Break'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Rain delay, bad light, etc.',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _startBreak(String breakType) async {
    if (widget.match.isMatchBreakActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A break is already active')),
      );
      return;
    }

    String reason = '';
    if (breakType == 'Rain' || breakType == 'Other') {
      final entered = await _promptReason(breakType);
      if (entered == null || !mounted) return;
      if (entered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a reason')),
        );
        return;
      }
      reason = entered;
    }

    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _starting = true);
    try {
      await ref.read(matchRepositoryProvider).startMatchBreak(
            matchId: widget.match.id,
            breakType: breakType,
            startedBy: uid,
            reason: reason,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start break: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final history = widget.match.matchBreakHistory;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Match Breaks'),
            if (widget.match.isMatchBreakActive)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                child: Text(
                  '${widget.match.activeMatchBreak!.breakType} break in progress — use the banner to resume.',
                  style: TextStyle(
                    color: cf.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemCount: _types.length,
                itemBuilder: (context, i) {
                  final t = _types[i];
                  return Material(
                    color: cf.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _starting || widget.match.isMatchBreakActive
                          ? null
                          : () => _startBreak(t.label),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.icon, color: cf.accent, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            t.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (history.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Text(
                  'Break History',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...history.reversed.take(5).map(
                    (e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(e.breakType),
                      subtitle: Text(e.displayLabel),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreakType {
  const _BreakType(this.label, this.icon);
  final String label;
  final IconData icon;
}

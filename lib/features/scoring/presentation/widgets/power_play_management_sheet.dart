import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../utils/scoring_display_utils.dart';

/// Live-scoring powerplay editor — same over-grid UX as match-start setup.
class PowerPlayManagementSheet extends ConsumerStatefulWidget {
  const PowerPlayManagementSheet({super.key, required this.match});

  final MatchModel match;

  static Future<void> show(BuildContext context, MatchModel match) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      builder: (_) => PowerPlayManagementSheet(match: match),
    );
  }

  @override
  ConsumerState<PowerPlayManagementSheet> createState() =>
      _PowerPlayManagementSheetState();
}

class _PowerPlayManagementSheetState
    extends ConsumerState<PowerPlayManagementSheet> {
  late List<List<int>> _slots;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.match.rules.powerplaySlots;
    _slots = List.generate(3, (i) {
      if (i < initial.length) {
        return List<int>.from(initial[i])..sort();
      }
      return <int>[];
    });
  }

  void _toggle(int slotIndex, int over) {
    setState(() {
      final usedElsewhere = <int>{};
      for (var i = 0; i < _slots.length; i++) {
        if (i != slotIndex) usedElsewhere.addAll(_slots[i]);
      }
      final slot = List<int>.from(_slots[slotIndex]);
      if (slot.contains(over)) {
        slot.remove(over);
      } else if (!usedElsewhere.contains(over)) {
        slot.add(over);
        slot.sort();
      }
      _slots[slotIndex] = slot;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final rules = widget.match.rules.copyWith(powerplaySlots: _slots);
      await ref.read(matchRepositoryProvider).updateMatchRules(
            widget.match.id,
            rules,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Power plays updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final totalOvers = widget.match.rules.totalOvers.clamp(1, 50);
    final inn = widget.match.currentInnings;
    final activeLabel = inn != null
        ? ScoringDisplayUtils.activePowerplayLabel(widget.match, inn)
        : null;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Select power play overs'),
            if (activeLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  0,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Text(
                  'Current active: $activeLabel',
                  style: TextStyle(
                    color: cf.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: AppDimens.listPadding,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(height: AppDimens.spaceLg),
                    Text(
                      'Power play ${i + 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    _OverGrid(
                      totalOvers: totalOvers,
                      selected: _slots[i],
                      usedElsewhere: {
                        for (var j = 0; j < 3; j++)
                          if (j != i) ..._slots[j],
                      },
                      onToggle: (over) => _toggle(i, over),
                    ),
                  ],
                  const SizedBox(height: AppDimens.spaceMd),
                  Text(
                    '* Tap overs to assign. An over can only belong to one '
                    'power play.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cf.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppDimens.spaceXl),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    AppDimens.buttonHeightLarge,
                  ),
                  backgroundColor: cf.accent,
                ),
                child: Text(_saving ? 'Saving…' : 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverGrid extends StatelessWidget {
  const _OverGrid({
    required this.totalOvers,
    required this.selected,
    required this.usedElsewhere,
    required this.onToggle,
  });

  final int totalOvers;
  final List<int> selected;
  final Set<int> usedElsewhere;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: totalOvers,
      itemBuilder: (_, index) {
        final over = index + 1;
        final isSelected = selected.contains(over);
        final blocked = usedElsewhere.contains(over) && !isSelected;

        return Material(
          color: isSelected
              ? cf.accent
              : blocked
                  ? cf.sectionBackground.withValues(alpha: 0.5)
                  : cf.surface,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: blocked ? null : () => onToggle(over),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? cf.accent : cf.border,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$over',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : blocked
                          ? cf.textMuted
                          : cf.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

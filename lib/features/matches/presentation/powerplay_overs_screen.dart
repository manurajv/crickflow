import 'package:flutter/material.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';

/// Select over numbers for up to three powerplays (no overlap between slots).
class PowerplayOversScreen extends StatefulWidget {
  const PowerplayOversScreen({
    super.key,
    required this.totalOvers,
    required this.initialSlots,
  });

  final int totalOvers;
  final List<List<int>> initialSlots;

  @override
  State<PowerplayOversScreen> createState() => _PowerplayOversScreenState();
}

class _PowerplayOversScreenState extends State<PowerplayOversScreen> {
  late List<List<int>> _slots;

  @override
  void initState() {
    super.initState();
    _slots = List.generate(3, (i) {
      if (i < widget.initialSlots.length) {
        return List<int>.from(widget.initialSlots[i])..sort();
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

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final overs = widget.totalOvers.clamp(1, 50);

    return Scaffold(
      appBar: AppBar(title: const Text('Select power play overs')),
      body: ListView(
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
              totalOvers: overs,
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
            '* Batting power play overs can be adjusted later during scoring.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _slots),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, AppDimens.buttonHeightLarge),
              backgroundColor: cf.accent,
            ),
            child: const Text('Done'),
          ),
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

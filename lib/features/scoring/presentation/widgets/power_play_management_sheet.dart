import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
import '../utils/scoring_display_utils.dart';

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

class _PowerPlayEntry {
  _PowerPlayEntry({
    required this.nameCtrl,
    required this.startCtrl,
    required this.endCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;

  void dispose() {
    nameCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
  }
}

class _PowerPlayManagementSheetState
    extends ConsumerState<PowerPlayManagementSheet> {
  late List<_PowerPlayEntry> _entries;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final rules = widget.match.rules;
    _entries = List.generate(3, (i) {
      final slot = i < rules.powerplaySlots.length
          ? rules.powerplaySlots[i]
          : <int>[];
      final name = i < rules.powerplayLabels.length
          ? rules.powerplayLabels[i]
          : 'Power Play ${i + 1}';
      final start = slot.isEmpty ? '' : '${slot.first}';
      final end = slot.isEmpty ? '' : '${slot.last}';
      return _PowerPlayEntry(
        nameCtrl: TextEditingController(text: name),
        startCtrl: TextEditingController(text: start),
        endCtrl: TextEditingController(text: end),
      );
    });
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  List<List<int>> _buildSlots() {
    final total = widget.match.rules.totalOvers;
    final slots = <List<int>>[];
    for (final e in _entries) {
      final start = int.tryParse(e.startCtrl.text.trim());
      final end = int.tryParse(e.endCtrl.text.trim());
      if (start == null || end == null || start <= 0 || end < start) {
        slots.add([]);
        continue;
      }
      final overs = <int>[];
      for (var o = start; o <= end && o <= total; o++) {
        overs.add(o);
      }
      slots.add(overs);
    }
    return slots;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final labels = _entries.map((e) => e.nameCtrl.text.trim()).toList();
      final slots = _buildSlots();
      final rules = widget.match.rules.copyWith(
        powerplaySlots: slots,
        powerplayLabels: labels,
      );
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

  void _clearEntry(int index) {
    setState(() {
      _entries[index].startCtrl.clear();
      _entries[index].endCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inn = widget.match.currentInnings;
    final activeLabel = inn != null
        ? ScoringDisplayUtils.activePowerplayLabel(widget.match, inn)
        : null;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Power Play'),
            if (activeLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                child: Text(
                  'Current Active Power Play: $activeLabel',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                itemCount: _entries.length,
                itemBuilder: (context, i) {
                  final e = _entries[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: e.nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              hintText: 'Power Play ${i + 1}',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: e.startCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Start Over',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: e.endCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'End Over',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _clearEntry(i),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              child: CfButton(
                label: _saving ? 'Saving…' : 'Save To Match',
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

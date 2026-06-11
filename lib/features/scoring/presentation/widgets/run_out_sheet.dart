import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/dismissal_fielder.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/lineup_player.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../shared/widgets/fielder_picker_sheet.dart';
import 'crease_picker_sheets.dart';

/// Result of the run-out scoring sheet.
class RunOutResult {
  const RunOutResult({
    required this.dismissedPlayerId,
    required this.fielders,
    required this.directHit,
    required this.deliveryKind,
    required this.completedRuns,
    this.noBallRunsMode,
  });

  final String dismissedPlayerId;
  final List<DismissalFielder> fielders;
  final bool directHit;
  final RunOutDeliveryKind deliveryKind;
  /// Runs completed by batters before the dismissal (excluding wide/NB penalty).
  final int completedRuns;
  final NoBallRunsMode? noBallRunsMode;
}

/// Crease after run out: who faces next + who fills the vacant end.
typedef RunOutLineupResult = ({
  String strikerId,
  String strikerName,
  String nonStrikerId,
  String nonStrikerName,
});

/// Full run-out flow: sheet details + next-striker selection.
class RunOutFlowResult {
  const RunOutFlowResult({
    required this.runOut,
    required this.lineup,
  });

  final RunOutResult runOut;
  final RunOutLineupResult lineup;
}

typedef RunOutLineupResolver = Future<RunOutLineupResult?> Function(
  BuildContext context,
  RunOutResult runOut,
);

Future<RunOutFlowResult?> showRunOutSheet(
  BuildContext context, {
  required InningsModel innings,
  required MatchRulesModel rules,
  required List<LineupPlayer> bowlingSquad,
  required RunOutLineupResolver resolveLineup,
}) {
  return Navigator.of(context).push<RunOutFlowResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RunOutSheet(
        innings: innings,
        rules: rules,
        bowlingSquad: bowlingSquad,
        resolveLineup: resolveLineup,
      ),
    ),
  );
}

class RunOutSheet extends StatefulWidget {
  const RunOutSheet({
    super.key,
    required this.innings,
    required this.rules,
    required this.bowlingSquad,
    required this.resolveLineup,
  });

  final InningsModel innings;
  final MatchRulesModel rules;
  final List<LineupPlayer> bowlingSquad;
  final RunOutLineupResolver resolveLineup;

  @override
  State<RunOutSheet> createState() => _RunOutSheetState();
}

class _RunOutSheetState extends State<RunOutSheet> {
  String? _dismissedId;
  DismissalFielder? _fielder1;
  DismissalFielder? _fielder2;
  bool _directHit = false;
  RunOutDeliveryKind _delivery = RunOutDeliveryKind.normal;
  int _completedRuns = 0;
  NoBallRunsMode _noBallMode = NoBallRunsMode.bat;
  bool _submitting = false;

  CreaseBatterOption? get _striker => CreaseBatterOption.fromInnings(
        widget.innings,
        widget.innings.strikerId,
        roleLabel: 'Striker',
      );

  CreaseBatterOption? get _nonStriker => CreaseBatterOption.fromInnings(
        widget.innings,
        widget.innings.nonStrikerId,
        roleLabel: 'Non-striker',
      );

  Future<void> _pickFielder(int slot) async {
    final exclude = <String>{
      if (slot == 1 && _fielder2 != null) _fielder2!.playerId,
      if (slot == 2 && _fielder1 != null) _fielder1!.playerId,
    };
    final picked = await FielderPickerSheet.show(
      context,
      title: slot == 1 ? 'Select fielder' : 'Select assisting fielder',
      players: widget.bowlingSquad,
      excludeIds: exclude,
    );
    if (picked == null || !mounted) return;
    setState(() {
      final f = DismissalFielder(playerId: picked.id, playerName: picked.name);
      if (slot == 1) {
        _fielder1 = f;
      } else {
        _fielder2 = f;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_dismissedId == null) {
      _snack('Select which batter was run out');
      return;
    }
    if (_fielder1 == null) {
      _snack('Select at least one fielder');
      return;
    }
    if (_directHit && _fielder2 != null) {
      _snack('Direct hit allows only one fielder');
      return;
    }

    final fielders = <DismissalFielder>[
      _fielder1!,
      if (!_directHit && _fielder2 != null) _fielder2!,
    ];

    final runOut = RunOutResult(
      dismissedPlayerId: _dismissedId!,
      fielders: fielders,
      directHit: _directHit,
      deliveryKind: _delivery,
      completedRuns: _completedRuns,
      noBallRunsMode:
          _delivery == RunOutDeliveryKind.noBall ? _noBallMode : null,
    );

    setState(() => _submitting = true);
    try {
      final lineup = await widget.resolveLineup(context, runOut);
      if (!mounted || lineup == null) return;
      Navigator.pop(
        context,
        RunOutFlowResult(runOut: runOut, lineup: lineup),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Run out'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        children: [
          _sectionTitle('Who?'),
          Row(
            children: [
              if (_striker != null)
                Expanded(
                  child: _WhoCard(
                    option: _striker!,
                    selected: _dismissedId == _striker!.playerId,
                    onTap: () =>
                        setState(() => _dismissedId = _striker!.playerId),
                  ),
                ),
              if (_striker != null && _nonStriker != null)
                const SizedBox(width: AppDimens.spaceSm),
              if (_nonStriker != null)
                Expanded(
                  child: _WhoCard(
                    option: _nonStriker!,
                    selected: _dismissedId == _nonStriker!.playerId,
                    onTap: () =>
                        setState(() => _dismissedId = _nonStriker!.playerId),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _sectionTitle('Select fielder')),
              InkWell(
                onTap: () => setState(() {
                  _directHit = !_directHit;
                  if (_directHit) _fielder2 = null;
                }),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _directHit,
                          activeColor: AppColors.gold,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) => setState(() {
                            _directHit = v ?? false;
                            if (_directHit) _fielder2 = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Direct hit',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              Expanded(
                child: _FielderSlot(
                  label: 'Fielder 1',
                  fielder: _fielder1,
                  onTap: () => _pickFielder(1),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _FielderSlot(
                  label: 'Fielder 2',
                  fielder: _directHit ? null : _fielder2,
                  enabled: !_directHit,
                  onTap: _directHit ? null : () => _pickFielder(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _sectionTitle('Delivery type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DeliveryChip(
                label: 'WD (${rules.wideRuns})',
                selected: _delivery == RunOutDeliveryKind.wide,
                onTap: () => setState(() => _delivery = RunOutDeliveryKind.wide),
              ),
              _DeliveryChip(
                label: 'NB (${rules.noBallRuns})',
                selected: _delivery == RunOutDeliveryKind.noBall,
                onTap: () => setState(() => _delivery = RunOutDeliveryKind.noBall),
              ),
              _DeliveryChip(
                label: 'Bye',
                selected: _delivery == RunOutDeliveryKind.bye,
                onTap: () => setState(() => _delivery = RunOutDeliveryKind.bye),
              ),
              _DeliveryChip(
                label: 'LB',
                selected: _delivery == RunOutDeliveryKind.legBye,
                onTap: () => setState(() => _delivery = RunOutDeliveryKind.legBye),
              ),
              if (_delivery != RunOutDeliveryKind.normal)
                ActionChip(
                  label: const Text('Clear'),
                  onPressed: () => setState(() {
                    _delivery = RunOutDeliveryKind.normal;
                    _noBallMode = NoBallRunsMode.bat;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceLg),
          _sectionTitle('Runs scored'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [0, 1, 2, 3, 4]
                .map(
                  (r) => _RunChip(
                    label: '$r',
                    selected: _completedRuns == r,
                    onTap: () => setState(() => _completedRuns = r),
                  ),
                )
                .toList(),
          ),
          if (_delivery == RunOutDeliveryKind.noBall && _completedRuns > 0) ...[
            const SizedBox(height: AppDimens.spaceMd),
            _sectionTitle('No-ball runs off'),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<NoBallRunsMode>(
                    dense: true,
                    title: const Text('From bat', style: TextStyle(fontSize: 13)),
                    value: NoBallRunsMode.bat,
                    groupValue: _noBallMode,
                    activeColor: AppColors.gold,
                    onChanged: (v) => setState(() => _noBallMode = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<NoBallRunsMode>(
                    dense: true,
                    title: const Text('Bye', style: TextStyle(fontSize: 13)),
                    value: NoBallRunsMode.bye,
                    groupValue: _noBallMode,
                    activeColor: AppColors.gold,
                    onChanged: (v) => setState(() => _noBallMode = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<NoBallRunsMode>(
                    dense: true,
                    title: const Text('Leg bye', style: TextStyle(fontSize: 13)),
                    value: NoBallRunsMode.legBye,
                    groupValue: _noBallMode,
                    activeColor: AppColors.gold,
                    onChanged: (v) => setState(() => _noBallMode = v!),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'Out',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _WhoCard extends StatelessWidget {
  const _WhoCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CreaseBatterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.15)
          : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppDimens.spaceSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.surfaceElevated,
                child: Text(
                  option.name.isNotEmpty
                      ? option.name.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.check_circle, color: AppColors.gold, size: 20),
                ),
              const SizedBox(height: 8),
              Text(
                option.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                option.roleLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FielderSlot extends StatelessWidget {
  const _FielderSlot({
    required this.label,
    required this.fielder,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final DismissalFielder? fielder;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  fielder != null ? Icons.check_circle : Icons.sports,
                  size: 40,
                  color: fielder != null ? AppColors.gold : AppColors.textMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  fielder?.playerName ?? label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fielder != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryChip extends StatelessWidget {
  const _DeliveryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.gold.withValues(alpha: 0.35),
      checkmarkColor: AppColors.gold,
    );
  }
}

class _RunChip extends StatelessWidget {
  const _RunChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: selected ? AppColors.gold : AppColors.card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.border,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

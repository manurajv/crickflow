import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/dismissal_fielder.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/lineup_player.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../shared/widgets/fielder_picker_sheet.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';
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

Future<RunOutResult?> showRunOutSheet(
  BuildContext context, {
  required InningsModel innings,
  required MatchRulesModel rules,
  required List<LineupPlayer> bowlingSquad,
}) {
  return ScoringUiKit.showDraggableSheet<RunOutResult>(
    context,
    initialChildSize: 0.92,
    minChildSize: 0.55,
    maxChildSize: 0.95,
    isDismissible: false,
    builder: (ctx, controller) => RunOutSheet(
      innings: innings,
      rules: rules,
      bowlingSquad: bowlingSquad,
      scrollController: controller,
    ),
  );
}

class RunOutSheet extends StatefulWidget {
  const RunOutSheet({
    super.key,
    required this.innings,
    required this.rules,
    required this.bowlingSquad,
    required this.scrollController,
  });

  final InningsModel innings;
  final MatchRulesModel rules;
  final List<LineupPlayer> bowlingSquad;
  final ScrollController scrollController;

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
  bool _showValidation = false;

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

  bool get _dismissedMissing => _dismissedId == null;
  bool get _fielderMissing => _fielder1 == null;
  bool get _directHitConflict => _directHit && _fielder2 != null;
  bool get _isValid => !_dismissedMissing && !_fielderMissing && !_directHitConflict;

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

  void _submit() {
    if (!_isValid) {
      setState(() => _showValidation = true);
      return;
    }

    final fielders = <DismissalFielder>[
      _fielder1!,
      if (!_directHit && _fielder2 != null) _fielder2!,
    ];

    Navigator.pop(
      context,
      RunOutResult(
        dismissedPlayerId: _dismissedId!,
        fielders: fielders,
        directHit: _directHit,
        deliveryKind: _delivery,
        completedRuns: _completedRuns,
        noBallRunsMode:
            _delivery == RunOutDeliveryKind.noBall ? _noBallMode : null,
      ),
    );
  }

  Widget _validationMessage(String message) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.accentRed),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.accentRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rules = widget.rules;
    final showDismissedError = _showValidation && _dismissedMissing;
    final showFielderError = _showValidation && _fielderMissing;
    final showDirectHitError = _showValidation && _directHitConflict;

    return Material(
      color: AppColors.surface,
      child: Column(
        children: [
          ScoringSheetHeader(title: 'Run out'),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              children: [
                _sectionTitle('Who was run out?'),
                Row(
                  children: [
                    if (_striker != null)
                      Expanded(
                        child: _WhoCard(
                          option: _striker!,
                          selected: _dismissedId == _striker!.playerId,
                          hasError: showDismissedError,
                          onTap: () => setState(() {
                            _dismissedId = _striker!.playerId;
                            _showValidation = false;
                          }),
                        ),
                      ),
                    if (_striker != null && _nonStriker != null)
                      const SizedBox(width: AppDimens.spaceSm),
                    if (_nonStriker != null)
                      Expanded(
                        child: _WhoCard(
                          option: _nonStriker!,
                          selected: _dismissedId == _nonStriker!.playerId,
                          hasError: showDismissedError,
                          onTap: () => setState(() {
                            _dismissedId = _nonStriker!.playerId;
                            _showValidation = false;
                          }),
                        ),
                      ),
                  ],
                ),
                if (showDismissedError)
                  _validationMessage('Please select the dismissed batter.'),
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
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
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
                        hasError: showFielderError,
                        onTap: () {
                          _pickFielder(1);
                          setState(() => _showValidation = false);
                        },
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
                if (showFielderError)
                  _validationMessage('Please select the fielder.'),
                if (showDirectHitError)
                  _validationMessage(
                    'Direct hit allows only one fielder.',
                  ),
                const SizedBox(height: AppDimens.spaceLg),
                _sectionTitle('Run out type'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DeliveryChip(
                      label: 'Normal',
                      selected: _delivery == RunOutDeliveryKind.normal,
                      onTap: () => setState(() {
                        _delivery = RunOutDeliveryKind.normal;
                        _noBallMode = NoBallRunsMode.bat;
                      }),
                    ),
                    _DeliveryChip(
                      label: 'WD (${rules.wideRuns})',
                      selected: _delivery == RunOutDeliveryKind.wide,
                      onTap: () =>
                          setState(() => _delivery = RunOutDeliveryKind.wide),
                    ),
                    _DeliveryChip(
                      label: 'NB (${rules.noBallRuns})',
                      selected: _delivery == RunOutDeliveryKind.noBall,
                      onTap: () =>
                          setState(() => _delivery = RunOutDeliveryKind.noBall),
                    ),
                    _DeliveryChip(
                      label: 'Bye',
                      selected: _delivery == RunOutDeliveryKind.bye,
                      onTap: () =>
                          setState(() => _delivery = RunOutDeliveryKind.bye),
                    ),
                    _DeliveryChip(
                      label: 'LB',
                      selected: _delivery == RunOutDeliveryKind.legBye,
                      onTap: () => setState(
                          () => _delivery = RunOutDeliveryKind.legBye),
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
                if (_delivery == RunOutDeliveryKind.noBall &&
                    _completedRuns > 0) ...[
                  const SizedBox(height: AppDimens.spaceMd),
                  _sectionTitle('No-ball runs off'),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<NoBallRunsMode>(
                          dense: true,
                          title: const Text('From bat',
                              style: TextStyle(fontSize: 13)),
                          value: NoBallRunsMode.bat,
                          groupValue: _noBallMode,
                          activeColor: AppColors.gold,
                          onChanged: (v) => setState(() => _noBallMode = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<NoBallRunsMode>(
                          dense: true,
                          title:
                              const Text('Bye', style: TextStyle(fontSize: 13)),
                          value: NoBallRunsMode.bye,
                          groupValue: _noBallMode,
                          activeColor: AppColors.gold,
                          onChanged: (v) => setState(() => _noBallMode = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<NoBallRunsMode>(
                          dense: true,
                          title: const Text('Leg bye',
                              style: TextStyle(fontSize: 13)),
                          value: NoBallRunsMode.legBye,
                          groupValue: _noBallMode,
                          activeColor: AppColors.gold,
                          onChanged: (v) => setState(() => _noBallMode = v!),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppDimens.spaceMd),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                0,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
              ),
              child: FilledButton(
                onPressed: _isValid ? _submit : () => _submit(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                      AppColors.gold.withValues(alpha: 0.45),
                  disabledForegroundColor: Colors.black54,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text(
                  'Confirm run out',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
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
    this.hasError = false,
  });

  final CreaseBatterOption option;
  final bool selected;
  final VoidCallback onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.accentRed
        : selected
            ? AppColors.gold
            : AppColors.border;

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
              color: borderColor,
              width: selected || hasError ? 2 : 1,
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
                  child:
                      Icon(Icons.check_circle, color: AppColors.gold, size: 20),
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
    this.hasError = false,
  });

  final String label;
  final DismissalFielder? fielder;
  final VoidCallback? onTap;
  final bool enabled;
  final bool hasError;

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
              border: Border.all(
                color: hasError ? AppColors.accentRed : AppColors.border,
                width: hasError ? 2 : 1,
              ),
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

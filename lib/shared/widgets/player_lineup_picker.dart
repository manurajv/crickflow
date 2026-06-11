import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../data/models/lineup_player.dart';
import '../../features/matches/presentation/widgets/select_lineup_player_sheet.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';
import 'scoring_ui_kit.dart';

/// Striker, non-striker, and bowler selection from squad lists.
class PlayerLineupPicker extends StatefulWidget {
  const PlayerLineupPicker({
    super.key,
    required this.battingSquad,
    required this.bowlingSquad,
    this.initialStrikerId,
    this.initialNonStrikerId,
    this.initialBowlerId,
    this.wicketKeeperId,
    required this.onSave,
    this.isLoading = false,
  });

  final List<LineupPlayer> battingSquad;
  final List<LineupPlayer> bowlingSquad;
  final String? initialStrikerId;
  final String? initialNonStrikerId;
  final String? initialBowlerId;
  final String? wicketKeeperId;
  final bool isLoading;
  final void Function({
    required String strikerId,
    required String strikerName,
    required String nonStrikerId,
    required String nonStrikerName,
    required String bowlerId,
    required String bowlerName,
  }) onSave;

  static Future<void> show(
    BuildContext context, {
    required List<LineupPlayer> battingSquad,
    required List<LineupPlayer> bowlingSquad,
    String? initialStrikerId,
    String? initialNonStrikerId,
    String? initialBowlerId,
    String? wicketKeeperId,
    required void Function({
      required String strikerId,
      required String strikerName,
      required String nonStrikerId,
      required String nonStrikerName,
      required String bowlerId,
      required String bowlerName,
    }) onSave,
  }) {
    return ScoringUiKit.showDraggableSheet<void>(
      context,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (ctx, _) => PlayerLineupPicker(
        battingSquad: battingSquad,
        bowlingSquad: bowlingSquad,
        initialStrikerId: initialStrikerId,
        initialNonStrikerId: initialNonStrikerId,
        initialBowlerId: initialBowlerId,
        wicketKeeperId: wicketKeeperId,
        onSave: onSave,
      ),
    );
  }

  @override
  State<PlayerLineupPicker> createState() => _PlayerLineupPickerState();
}

class _PlayerLineupPickerState extends State<PlayerLineupPicker> {
  LineupPlayer? _striker;
  LineupPlayer? _nonStriker;
  LineupPlayer? _bowler;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(PlayerLineupPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.battingSquad != widget.battingSquad ||
        oldWidget.bowlingSquad != widget.bowlingSquad) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _striker = _pick(
          widget.battingSquad,
          widget.initialStrikerId,
          0,
        ) ??
        widget.battingSquad.firstOrNull;
    _nonStriker = _pick(
          widget.battingSquad,
          widget.initialNonStrikerId,
          1,
        ) ??
        widget.battingSquad.skip(1).firstOrNull ??
        _striker;
    _bowler = _pick(widget.bowlingSquad, widget.initialBowlerId, 0) ??
        widget.bowlingSquad.firstOrNull;
  }

  LineupPlayer? _pick(List<LineupPlayer> squad, String? id, int fallbackIndex) {
    if (id != null) {
      return squad.where((p) => p.id == id).firstOrNull;
    }
    if (squad.length > fallbackIndex) return squad[fallbackIndex];
    return null;
  }

  Map<String, String> get _bowlerDisabledIds {
    final keeperId = widget.wicketKeeperId;
    if (keeperId == null || keeperId.isEmpty) return const {};
    return {keeperId: ScoringDisplayUtils.wicketKeeperCannotBowlReason};
  }

  Future<void> _pickStriker() async {
    final p = await SelectLineupPlayerSheet.show(
      context,
      title: 'Select striker',
      players: widget.battingSquad,
      excludeIds: {_nonStriker?.id ?? ''},
    );
    if (p != null && mounted) setState(() => _striker = p);
  }

  Future<void> _pickNonStriker() async {
    final p = await SelectLineupPlayerSheet.show(
      context,
      title: 'Select non-striker',
      players: widget.battingSquad,
      excludeIds: {_striker?.id ?? ''},
    );
    if (p != null && mounted) setState(() => _nonStriker = p);
  }

  Future<void> _pickBowler() async {
    final squad = widget.bowlingSquad.isNotEmpty
        ? widget.bowlingSquad
        : widget.battingSquad;
    final p = await SelectLineupPlayerSheet.show(
      context,
      title: 'Select bowler',
      players: squad,
      disabledIds: _bowlerDisabledIds,
    );
    if (p != null && mounted) setState(() => _bowler = p);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Material(
        color: AppColors.surface,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimens.spaceLg),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (widget.battingSquad.isEmpty) {
      return Material(
        color: AppColors.surface,
        child: Column(
          children: [
            ScoringSheetHeader(
              title: 'Edit lineup',
              trailing: ScoringUiKit.sheetCloseButton(context),
            ),
            const Padding(
              padding: EdgeInsets.all(AppDimens.spaceMd),
              child: Text(
                'Add players to teams in Firestore, or link team IDs on this match.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScoringSheetHeader(
            title: 'Edit lineup',
            trailing: ScoringUiKit.sheetCloseButton(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SlotRow(
                  label: 'Striker',
                  player: _striker,
                  onTap: _pickStriker,
                  icon: Icons.sports_cricket,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _SlotRow(
                  label: 'Non-striker',
                  player: _nonStriker,
                  onTap: _pickNonStriker,
                  icon: Icons.sports_cricket_outlined,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                _SlotRow(
                  label: 'Bowler',
                  player: _bowler,
                  onTap: _pickBowler,
                  icon: Icons.sports_baseball_outlined,
                ),
                const SizedBox(height: AppDimens.spaceLg),
                FilledButton(
                  onPressed: _striker == null ||
                          _nonStriker == null ||
                          _bowler == null
                      ? null
                      : () {
                          widget.onSave(
                            strikerId: _striker!.id,
                            strikerName: _striker!.name,
                            nonStrikerId: _nonStriker!.id,
                            nonStrikerName: _nonStriker!.name,
                            bowlerId: _bowler!.id,
                            bowlerName: _bowler!.name,
                          );
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text(
                    'Apply lineup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.player,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final LineupPlayer? player;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceElevated,
                child: Icon(icon, size: 20, color: AppColors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      player?.name ?? 'Tap to select',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: player != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
